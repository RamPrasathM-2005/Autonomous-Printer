import os
import re
import subprocess
import uuid
from pathlib import Path
from typing import Dict, Any, Tuple
from app.config import config
from app.utils.errors import CupsException
from app.utils.logging import agent_logger

class CupsService:
    def __init__(self):
        self.printer_name = config.PRINTER_NAME
        self.mock_mode = config.MOCK_CUPS

        # Try pycups if available
        self.has_pycups = False
        try:
            import cups
            self.cups = cups
            self.has_pycups = True
        except ImportError:
            self.cups = None

    def build_cups_options(self, settings: Dict[str, Any]) -> Dict[str, str]:
        """Maps business print settings to standard CUPS PPD options."""
        options: Dict[str, str] = {}

        # Copies
        copies = settings.get("copies", 1)
        try:
            copies = max(1, int(copies))
        except (ValueError, TypeError):
            copies = 1
        options["copies"] = str(copies)

        # Page ranges (CUPS page-ranges fails with 'Bad page-ranges values 0-0.' if 'all' is passed)
        raw_range = settings.get("pageRange") or settings.get("page_range")
        if raw_range:
            range_str = str(raw_range).strip()
            range_lower = range_str.lower()
            if range_lower in ("odd", "odds"):
                options["page-set"] = "odd"
            elif range_lower in ("even", "evens"):
                options["page-set"] = "even"
            elif range_lower not in ("all", "all pages", "none", "", "*") and re.match(r'^[0-9\s,\-]+$', range_str):
                options["page-ranges"] = range_str.replace(" ", "")

        # Color mode: Color vs Grayscale (Monochrome)
        raw_colour = settings.get("colour")
        if raw_colour is None:
            raw_colour = settings.get("isColor")
        if raw_colour is None:
            c_mode = str(settings.get("colorMode") or settings.get("color_mode") or "").strip().upper()
            raw_colour = (c_mode in ("COLOR", "COLOUR", "RGB"))

        is_color = False
        if isinstance(raw_colour, bool):
            is_color = raw_colour
        elif isinstance(raw_colour, (int, float)):
            is_color = bool(raw_colour)
        elif isinstance(raw_colour, str):
            is_color = raw_colour.strip().lower() in ("true", "1", "color", "colour", "rgb", "yes")

        # Color mode
        options["print-color-mode"] = "color" if is_color else "monochrome"

        # Duplex / Sides
        sides = settings.get("sides", "one-sided")
        if sides in ["two-sided-long-edge", "two-sided-short-edge", "duplex"]:
            options["sides"] = "two-sided-long-edge" if sides in ["two-sided-long-edge", "duplex"] else "two-sided-short-edge"
            options["Duplex"] = "DuplexNoTumble" if sides in ["two-sided-long-edge", "duplex"] else "DuplexTumble"
        else:
            options["sides"] = "one-sided"
            options["Duplex"] = "None"

        # Media / Paper Size (A4, A5, A6, Letter, Legal, Executive)
        raw_paper = str(settings.get("paperSize") or settings.get("paper_size", "A4")).strip()
        paper_map = {
            "a4": "A4",
            "a5": "A5",
            "a6": "A6",
            "letter": "Letter",
            "legal": "Legal",
            "executive": "Executive"
        }
        paper_size = paper_map.get(raw_paper.lower(), raw_paper)
        options["media"] = paper_size
        options["PageSize"] = paper_size
        options["fit-to-page"] = "True"

        # Paper tray: Auto selection by default so it picks whichever tray has paper
        tray = settings.get("tray") or settings.get("inputSlot") or settings.get("input_slot") or settings.get("paper_source")
        if tray:
            tray_str = str(tray).strip().lower()
            if "1" in tray_str:
                options["InputSlot"] = "Tray1"
            elif "2" in tray_str:
                options["InputSlot"] = "Tray2"
            elif "3" in tray_str:
                options["InputSlot"] = "Tray3"
            else:
                options["InputSlot"] = "Auto"
        else:
            options["InputSlot"] = "Auto"

        # Print Resolution / Quality (FastRes1200, 600dpi, ProRes1200)
        res = settings.get("resolution") or settings.get("printQuality") or settings.get("print_quality")
        if res:
            res_str = str(res).strip().lower()
            if "prores" in res_str or "1200x1200" in res_str:
                options["Resolution"] = "1200x1200dpi"
                options["HPResolution"] = "ProRes1200"
            elif "fastres" in res_str:
                options["Resolution"] = "600x600dpi"
                options["HPResolution"] = "FastRes1200"
            elif "600" in res_str:
                options["Resolution"] = "600x600dpi"
                options["HPResolution"] = "600dpi"

        # Orientation
        orientation = settings.get("orientation", "portrait").lower()
        if orientation == "landscape":
            options["orientation-requested"] = "4" # CUPS standard for 90 deg / landscape
        else:
            options["orientation-requested"] = "3" # Portrait

        return options

    def prepare_printable_file(self, file_path: Path, settings: Dict[str, Any]) -> Path:
        """
        Prepares a physical print-ready file:
        - If odd/even or custom page ranges are specified, creates a sliced PDF.
        - Rotates pages if landscape or portrait orientation is requested.
        - If image, converts to PDF with proper orientation.
        """
        from pypdf import PdfReader, PdfWriter
        from PIL import Image

        raw_range = settings.get("pageRange") or settings.get("page_range")
        orientation = str(settings.get("orientation", "portrait")).strip().lower()
        suffix = file_path.suffix.lower()

        needs_processing = False
        is_odd = False
        is_even = False
        custom_pages = None

        if raw_range:
            r_str = str(raw_range).strip().lower()
            if r_str in ("odd", "odds"):
                is_odd = True
                needs_processing = True
            elif r_str in ("even", "evens"):
                is_even = True
                needs_processing = True
            elif r_str not in ("all", "all pages", "none", "", "*") and re.match(r'^[0-9\s,\-]+$', r_str):
                needs_processing = True
                custom_pages = set()
                for part in r_str.split(','):
                    part = part.strip()
                    if '-' in part:
                        s_str, e_str = part.split('-', 1)
                        if s_str.isdigit() and e_str.isdigit():
                            for n in range(int(s_str), int(e_str) + 1):
                                custom_pages.add(n)
                    elif part.isdigit():
                        custom_pages.add(int(part))

        if orientation in ("landscape", "portrait"):
            needs_processing = True

        if suffix in [".png", ".jpg", ".jpeg", ".webp"]:
            needs_processing = True

        if not needs_processing:
            return file_path

        out_dir = Path(__file__).resolve().parent.parent.parent / "storage" / "processed_jobs"
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"proc_{uuid.uuid4().hex[:8]}_{file_path.stem}.pdf"

        try:
            if suffix in [".png", ".jpg", ".jpeg", ".webp"]:
                with Image.open(file_path) as img:
                    if orientation == "landscape" and img.width < img.height:
                        img = img.rotate(90, expand=True)
                    elif orientation == "portrait" and img.width > img.height:
                        img = img.rotate(90, expand=True)
                    rgb_img = img.convert("RGB")
                    rgb_img.save(out_path, "PDF")
                return out_path

            if suffix == ".pdf":
                reader = PdfReader(str(file_path))
                total_pages = len(reader.pages)
                writer = PdfWriter()

                for idx, page in enumerate(reader.pages):
                    page_num = idx + 1
                    if is_odd and page_num % 2 == 0:
                        continue
                    if is_even and page_num % 2 != 0:
                        continue
                    if custom_pages is not None and page_num not in custom_pages:
                        continue

                    w = float(page.mediabox.width)
                    h = float(page.mediabox.height)
                    if orientation == "landscape" and w < h:
                        page.rotate(90)
                    elif orientation == "portrait" and w > h:
                        page.rotate(90)

                    writer.add_page(page)

                if len(writer.pages) > 0:
                    with open(out_path, "wb") as f_out:
                        writer.write(f_out)
                    return out_path
        except Exception as e:
            agent_logger.warning(f"Error in prepare_printable_file ({e}), falling back to original: {file_path}")

        return file_path

    def is_printer_out_of_paper(self) -> bool:
        """Checks if the printer currently has a media-empty or paper-out condition."""
        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                attrs = conn.getPrinterAttributes(self.printer_name)
                reasons = [str(r).lower() for r in attrs.get("printer-state-reasons", [])]
                msg = str(attrs.get("printer-state-message") or "").lower()
                return any(
                    r in reasons for r in ["media-empty", "media-needed", "media-empty-warning", "media-empty-error", "input-tray-missing"]
                ) or ("out of paper" in msg or "tray empty" in msg or "load paper" in msg or "media empty" in msg)
            except Exception:
                pass

        try:
            res = subprocess.run(["lpstat", "-p", self.printer_name, "-l"], capture_output=True, text=True)
            out_lower = res.stdout.lower()
            return ("media-empty" in out_lower or "out of paper" in out_lower or "tray empty" in out_lower or "load paper" in out_lower)
        except Exception:
            return False

    def submit_job(self, file_path: Path, settings: Dict[str, Any]) -> str:
        """
        Submits file to CUPS printer with formatted options.
        Supports dynamic selection between multiple printers connected to the station.
        Returns the CUPS Job ID.
        """
        printable_file = self.prepare_printable_file(file_path, settings)
        options = self.build_cups_options(settings)

        # Dynamic printer selection
        target_printer = settings.get("cups_printer_name") or settings.get("printer_name") or self.printer_name
        if any(k in str(target_printer) for k in ["E9A0F4", "Unit 2", "Printer_2", "central_02"]):
            target_printer = "HP_LaserJet_400_M401dn_E9A0F4"
        elif any(k in str(target_printer) for k in ["F36EC0", "Unit 1", "central_01"]):
            target_printer = "HP_LaserJet_400_M401dn_F36EC0"

        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                available = conn.getPrinters()
                if target_printer not in available:
                    agent_logger.warning(f"Selected printer '{target_printer}' not found in CUPS. Available: {list(available.keys())}. Falling back to '{self.printer_name}'.")
                    target_printer = self.printer_name
            except Exception:
                pass

        # If printable_file was already sliced with custom/odd/even ranges, remove page-ranges / page-set from CUPS options
        if printable_file != file_path:
            options.pop("page-ranges", None)
            options.pop("page-set", None)

        agent_logger.info(f"Submitting {printable_file.name} to target printer '{target_printer}' with options: {options}")

        # Store a verified copy in system storage so the user can inspect printed files
        try:
            printed_dir = Path(__file__).resolve().parent.parent.parent.parent / "storage" / "printed_outputs"
            printed_dir.mkdir(parents=True, exist_ok=True)
            mode_tag = "COLOR" if options.get("print-color-mode") == "color" else "GRAYSCALE"
            saved_copy = printed_dir / f"PRINTED_{mode_tag}_{printable_file.name}"
            import shutil
            if printable_file.exists() and printable_file.resolve() != saved_copy.resolve():
                shutil.copy2(printable_file, saved_copy)
                agent_logger.info(f"Preserved physical print file in storage: {saved_copy}")
        except Exception as copy_err:
            agent_logger.warning(f"Could not save copy to printed_outputs: {copy_err}")

        # If in Mock mode or Windows without native CUPS
        if self.mock_mode or (os.name == 'nt' and not self.has_pycups):
            mock_id = f"cups-{uuid.uuid4().hex[:8]}"
            agent_logger.info(f"[MOCK_CUPS] Successfully submitted simulated print job ID: {mock_id} to '{target_printer}'")
            return mock_id

        # 1. Native pycups submission if installed
        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                job_id = conn.printFile(
                    target_printer,
                    str(printable_file),
                    f"Job_{printable_file.name}",
                    options
                )
                agent_logger.info(f"pycups successfully submitted job ID: {job_id} to '{target_printer}'")
                return str(job_id)
            except Exception as e:
                agent_logger.warning(f"pycups printFile failed ({e}). Attempting CLI lp fallback...")

        # 2. CLI 'lp' command fallback
        cmd = ["lp", "-d", target_printer]
        for opt_k, opt_v in options.items():
            cmd.extend(["-o", f"{opt_k}={opt_v}"])
        cmd.append(str(printable_file))

        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                err_msg = result.stderr.strip() or f"lp exited with code {result.returncode}"
                agent_logger.error(f"CUPS lp command failed ({err_msg}): {' '.join(cmd)}")
                raise CupsException(f"Failed to print to physical printer '{target_printer}': {err_msg}")

            output = result.stdout.strip()
            cups_id = output.split()[3] if len(output.split()) >= 4 else f"{uuid.uuid4().hex[:6]}"
            agent_logger.info(f"CLI lp successfully submitted job ID: {cups_id} to '{target_printer}'")
            return cups_id
        except CupsException:
            raise
        except Exception as e:
            agent_logger.error(f"CUPS submission failed on physical printer '{target_printer}': {e}")
            raise CupsException(f"Failed to print to physical printer '{target_printer}': {e}")

    def monitor_job(self, cups_job_id: str, on_status_callback=None, target_printer: str = None) -> str:
        """
        Checks status of CUPS job until completion, failure, or out-of-paper.
        Calls on_status_callback(status, error_code, message) when paper is empty.
        Returns: COMPLETED, OUT_OF_PAPER, or FAILED
        """
        import time

        printer_name = target_printer or self.printer_name

        if self.mock_mode or cups_job_id.startswith("cups-"):
            time.sleep(2)
            return "COMPLETED"

        for _ in range(90):  # Poll up to 180 seconds
            job_in_queue = False
            job_state = None

            if self.has_pycups:
                try:
                    conn = self.cups.Connection(host=config.CUPS_SERVER)
                    jobs = conn.getJobs()
                    if int(cups_job_id) in jobs:
                        job_in_queue = True
                        job_state = jobs[int(cups_job_id)].get("job-state", 0)
                except Exception:
                    pass
            else:
                try:
                    res = subprocess.run(["lpstat", "-o", printer_name], capture_output=True, text=True)
                    if cups_job_id in res.stdout:
                        job_in_queue = True
                except Exception:
                    pass

            if not job_in_queue:
                agent_logger.info(f"CUPS job {cups_job_id} cleared printer queue.")
                return "COMPLETED"

            if job_state in (7, 8):
                return "FAILED"

            if self.is_printer_out_of_paper():
                agent_logger.warning(f"Printer '{printer_name}' is OUT OF PAPER for job {cups_job_id}!")
                if on_status_callback:
                    on_status_callback(
                        status="PRINTING",
                        error_code="OUT_OF_PAPER",
                        message=f"Printer '{printer_name}' is out of paper. Please load paper into the tray to continue printing."
                    )
            time.sleep(2)

        if self.is_printer_out_of_paper():
            return "OUT_OF_PAPER"

        return "COMPLETED"

cups_service = CupsService()
