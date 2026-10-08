import os
import re
import socket
import subprocess
import uuid
import threading
from pathlib import Path
from typing import Dict, Any, Tuple
from app.config import config
from app.utils.errors import CupsException
from app.utils.logging import agent_logger
from app.services.file_service import file_service


class CupsService:
    @staticmethod
    def is_physical_uri(uri: str) -> bool:
        """Reject file sinks and missing devices in physical mode."""
        return str(uri or "").lower().startswith(("usb://", "hp:/", "hpfax:/", "ipp://", "ipps://", "socket://", "lpd://", "dnssd://", "parallel:/", "serial:/"))

    def __init__(self):
        self._local = threading.local()
        self.printer_name = config.PRINTER_NAME
        self.mock_mode = config.MOCK_CUPS

        # Try pycups if available (native on Linux / Raspberry Pi OS)
        self.has_pycups = False
        try:
            import importlib
            self.cups = importlib.import_module("cups")
            self.has_pycups = True
        except (ImportError, ModuleNotFoundError):
            self.cups = None

    @property
    def last_prepared_file(self):
        return getattr(self._local, "prepared_file", None)

    @last_prepared_file.setter
    def last_prepared_file(self, value):
        self._local.prepared_file = value

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

        out_dir = file_service.processed_dir
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

                if not writer.pages:
                    raise CupsException("The selected page range contains no pages.", error_code="INVALID_PAGE_RANGE")
                with open(out_path, "wb") as f_out:
                    writer.write(f_out)
                return out_path
        except Exception as e:
            out_path.unlink(missing_ok=True)
            agent_logger.exception("Cannot prepare print document %s", file_path.name)
            raise CupsException("Document preparation failed. Check the file and page selection.", error_code="DOCUMENT_PREPARATION_FAILED") from e

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
        self.last_prepared_file = None
        printable_file = self.prepare_printable_file(file_path, settings)
        self.last_prepared_file = printable_file if printable_file != file_path else None
        options = self.build_cups_options(settings)

        # Dynamic printer selection
        target_printer = settings.get("cups_printer_name") or settings.get("printer_name") or self.printer_name
        if not target_printer:
            raise CupsException("No CUPS printer is assigned to this job.")
        if self.has_pycups and not self.mock_mode:
            conn = self.cups.Connection(host=config.CUPS_SERVER)
            printers = conn.getPrinters()
            if target_printer not in printers:
                raise CupsException(f"Assigned printer '{target_printer}' does not exist in CUPS.")
            if not self.is_physical_uri(printers[target_printer].get("device-uri")):
                raise CupsException(f"Assigned printer '{target_printer}' has no physical device URI. Correct its CUPS queue.", error_code="INVALID_PRINTER_URI")

        # If printable_file was already sliced with custom/odd/even ranges, remove page-ranges / page-set from CUPS options
        if printable_file != file_path:
            options.pop("page-ranges", None)
            options.pop("page-set", None)

        agent_logger.info(f"Submitting {printable_file.name} to target printer '{target_printer}' with options: {options}")

        self.last_prepared_file = printable_file if printable_file != file_path else None

        # If in Mock mode or Windows without native CUPS
        if self.mock_mode:
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
                raise CupsException(f"CUPS submission outcome is unknown: {e}. Inspect the queue before retrying.", error_code="SUBMISSION_UNKNOWN") from e

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

        if self.mock_mode:
            time.sleep(2)
            return "COMPLETED"

        # Missing queue entries and timeouts are not proof of completion.
        last_reported = None
        while True:
            try:
                if self.has_pycups:
                    conn = self.cups.Connection(host=config.CUPS_SERVER)
                    job_id = int(str(cups_job_id).rsplit("-", 1)[-1])
                    attrs = conn.getJobAttributes(job_id)
                    job_state = attrs.get("job-state")
                    if job_state == 9:
                        return "COMPLETED"
                    if job_state in (7, 8):
                        return "FAILED"
                    reasons = conn.getPrinterAttributes(printer_name).get("printer-state-reasons", [])
                    paper_empty = any("media-empty" in str(reason) for reason in reasons)
                else:
                    # CLI fallback consults retained completed-job history as well as active jobs.
                    res = subprocess.run(["lpstat", "-h", config.CUPS_SERVER, "-W", "completed", "-o", printer_name], capture_output=True, text=True, timeout=10)
                    if res.returncode != 0:
                        raise CupsException(res.stderr or "Cannot read CUPS job history")
                    if any(line.split()[0] == str(cups_job_id) for line in res.stdout.splitlines() if line.split()):
                        # lpstat completed includes canceled/aborted jobs: require pycups for reliable outcomes.
                        return "STATUS_UNKNOWN"
                    paper_empty = self.is_printer_out_of_paper()
                if on_status_callback and paper_empty != last_reported:
                    on_status_callback(status="PRINTING", error_code="OUT_OF_PAPER" if paper_empty else None,
                                       message="Load paper to continue printing." if paper_empty else None)
                    last_reported = paper_empty
            except Exception as exc:
                agent_logger.warning(f"Cannot confirm CUPS job {cups_job_id}: {exc}")
                return "STATUS_UNKNOWN"
            time.sleep(2)

    def get_detected_printers(self) -> list:
        """
        Scans CUPS for all installed and detected printers.
        Extracts CUPS queue name, device URI, IP address (if network-based), and state.
        Returns empty list when no physical/CUPS printers are available.
        """
        printers_list = []

        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                cups_printers = conn.getPrinters()
                for name, info in cups_printers.items():
                    uri = info.get("device-uri", "")
                    state_num = info.get("printer-state", 3)
                    state_str = "READY"
                    if state_num == 4:
                        state_str = "BUSY"
                    elif state_num == 5:
                        state_str = "OFFLINE"
                    if not self.mock_mode and not self.is_physical_uri(uri):
                        state_str = "OFFLINE"

                    ip = None
                    if uri:
                        ip_match = re.search(r"://([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)", uri)
                        if ip_match:
                            ip = ip_match.group(1)

                    printers_list.append({
                        "cups_printer_name": name,
                        "device_uri": uri,
                        "ip_address": ip,
                        "status": state_str,
                        "jobs": 0,
                    })
                return printers_list
            except Exception as e:
                agent_logger.warning(f"Error querying pycups for detected printers: {e}")

        # CLI fallback via lpstat -v and lpstat -p
        try:
            res_v = subprocess.run(["lpstat", "-v"], capture_output=True, text=True)
            if res_v.returncode == 0 and res_v.stdout.strip():
                for line in res_v.stdout.strip().splitlines():
                    # Format: "device for <printer_name>: <uri>"
                    m = re.match(r"device for ([^:]+):\s*(.+)", line.strip())
                    if m:
                        p_name = m.group(1).strip()
                        uri = m.group(2).strip()
                        ip = None
                        ip_match = re.search(r"://([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)", uri)
                        if ip_match:
                            ip = ip_match.group(1)

                        printers_list.append({
                            "cups_printer_name": p_name,
                            "device_uri": uri,
                            "ip_address": ip,
                            "status": "OFFLINE",
                            "jobs": 0,
                        })
                return printers_list
        except Exception as e:
            agent_logger.debug(f"lpstat fallback error: {e}")

        # If in Mock mode and mock fallback is active
        if self.mock_mode:
            # If default PRINTER_NAME is configured, return mock entries
            if self.printer_name:
                return [{
                    "cups_printer_name": self.printer_name,
                    "device_uri": f"socket://127.0.0.1:9100",
                    "ip_address": "127.0.0.1",
                    "status": "READY",
                    "jobs": 0,
                }]

        return []

    def verify_printer(
        self,
        cups_printer_name: str,
        ip_address: str = None,
        device_uri: str = None,
        protocol: str = "Socket"
    ) -> dict:
        """
        Performs diagnostic validation of a printer:
        1. Verifies if printer exists in CUPS.
        2. Probes network reachability using static IP or device URI.
        3. Verifies printer availability (not stopped or error).
        """
        import socket
        cups_exists = False
        reachable = False
        available = False
        messages = []

        cups_name = (cups_printer_name or "").strip()
        target_ip = (ip_address or "").strip()
        uri = (device_uri or "").strip()
        proto = (protocol or "Socket").strip().lower()

        # Extract target IP from URI if not directly given
        if not target_ip and uri:
            ip_m = re.search(r"://([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)", uri)
            if ip_m:
                target_ip = ip_m.group(1)

        # 1. Check CUPS existence & status
        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                printers = conn.getPrinters()
                if cups_name in printers:
                    cups_exists = True
                    info = printers[cups_name]
                    state = info.get("printer-state", 3)
                    available = (state != 5)
                    if not available:
                        messages.append(f"Printer '{cups_name}' exists in CUPS but is STOPPED/DISABLED.")
                else:
                    messages.append(f"Printer '{cups_name}' does not exist in CUPS.")
            except Exception as e:
                agent_logger.warning(f"CUPS connection check failed: {e}")
                messages.append(f"CUPS service error: {e}")
        else:
            try:
                res = subprocess.run(["lpstat", "-p", cups_name], capture_output=True, text=True)
                if res.returncode == 0:
                    cups_exists = True
                    out_lower = res.stdout.lower()
                    if "disabled" in out_lower or "stopped" in out_lower:
                        available = False
                        messages.append(f"CUPS queue '{cups_name}' is disabled or stopped.")
                    else:
                        available = True
                else:
                    messages.append(f"Printer '{cups_name}' was not found in CUPS.")
            except Exception as e:
                messages.append(f"CUPS lpstat error: {e}")

        # If Mock CUPS mode is enabled and cups was not found via real CUPS
        if not cups_exists and self.mock_mode:
            if cups_name:
                cups_exists = True
                available = True

        # 2. Network Reachability Probe
        port = 9100
        if "ipp" in proto or "631" in uri:
            port = 631
        elif "lpd" in proto or "515" in uri:
            port = 515
        elif uri and ":" in uri:
            port_match = re.search(r":([0-9]{2,5})", uri.split("://")[-1] if "://" in uri else uri)
            if port_match:
                try:
                    port = int(port_match.group(1))
                except ValueError:
                    pass

        if target_ip:
            # Probe TCP socket on the configured IP:Port with a strict 2-second timeout
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(2.0)
                sock.connect((target_ip, port))
                sock.close()
                reachable = True
            except socket.timeout:
                reachable = False
                messages.append(f"Network probe timed out for {target_ip}:{port}. Printer is unreachable.")
            except socket.error as se:
                reachable = False
                messages.append(f"Network connection failed to {target_ip}:{port} ({se}).")
        else:
            # No static IP or URI specified
            reachable = cups_exists
            if not target_ip:
                messages.append("No static IP address configured for network reachability probe.")

        # Determine overall success
        overall_success = cups_exists and reachable and available

        summary_msg = ""
        if overall_success:
            summary_msg = f"Printer '{cups_name}' verified: CUPS queue exists, reachable on {target_ip or 'CUPS'}:{port}, status available."
        else:
            summary_msg = " ; ".join(messages) if messages else "Printer verification failed."

        return {
            "success": overall_success,
            "cups_exists": cups_exists,
            "reachable": reachable,
            "available": available,
            "message": summary_msg
        }

cups_service = CupsService()
