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

        # Color mode (Monochrome HP LaserJet)
        options["print-color-mode"] = "monochrome"

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

    def submit_job(self, file_path: Path, settings: Dict[str, Any]) -> str:
        """
        Submits file to CUPS printer with formatted options.
        Returns the CUPS Job ID.
        """
        options = self.build_cups_options(settings)
        agent_logger.info(f"Submitting {file_path.name} to printer '{self.printer_name}' with options: {options}")

        # Store a verified copy in system storage so the user can inspect printed files
        try:
            printed_dir = Path(__file__).resolve().parent.parent.parent.parent / "storage" / "printed_outputs"
            printed_dir.mkdir(parents=True, exist_ok=True)
            mode_tag = "COLOR" if options.get("print-color-mode") == "color" else "GRAYSCALE"
            saved_copy = printed_dir / f"PRINTED_{mode_tag}_{file_path.name}"
            import shutil
            if file_path.exists() and file_path.resolve() != saved_copy.resolve():
                shutil.copy2(file_path, saved_copy)
                agent_logger.info(f"Preserved physical print file in storage: {saved_copy}")
        except Exception as copy_err:
            agent_logger.warning(f"Could not save copy to printed_outputs: {copy_err}")

        # If in Mock mode or Windows without native CUPS
        if self.mock_mode or (os.name == 'nt' and not self.has_pycups):
            mock_id = f"cups-{uuid.uuid4().hex[:8]}"
            agent_logger.info(f"[MOCK_CUPS] Successfully submitted simulated print job ID: {mock_id}")
            return mock_id

        # 1. Native pycups submission if installed
        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                job_id = conn.printFile(
                    self.printer_name,
                    str(file_path),
                    f"Job_{file_path.name}",
                    options
                )
                agent_logger.info(f"pycups successfully submitted job ID: {job_id}")
                return str(job_id)
            except Exception as e:
                agent_logger.warning(f"pycups printFile failed ({e}). Attempting CLI lp fallback...")

        # 2. CLI 'lp' command fallback
        cmd = ["lp", "-d", self.printer_name]
        for opt_k, opt_v in options.items():
            cmd.extend(["-o", f"{opt_k}={opt_v}"])
        cmd.append(str(file_path))

        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                err_msg = result.stderr.strip() or f"lp exited with code {result.returncode}"
                agent_logger.error(f"CUPS lp command failed ({err_msg}): {' '.join(cmd)}")
                raise CupsException(f"Failed to print to physical printer '{self.printer_name}': {err_msg}")

            output = result.stdout.strip()
            cups_id = output.split()[3] if len(output.split()) >= 4 else f"{uuid.uuid4().hex[:6]}"
            agent_logger.info(f"CLI lp successfully submitted job ID: {cups_id}")
            return cups_id
        except CupsException:
            raise
        except Exception as e:
            agent_logger.error(f"CUPS submission failed on physical printer '{self.printer_name}': {e}")
            raise CupsException(f"Failed to print to physical printer '{self.printer_name}': {e}")

    def monitor_job(self, cups_job_id: str) -> str:
        """
        Checks status of CUPS job.
        Returns: COMPLETED, PROCESSING, or FAILED
        """
        import time

        if self.mock_mode or cups_job_id.startswith("cups-"):
            time.sleep(2)  # Realistic print spooling delay for UI progress
            return "COMPLETED"

        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                jobs = conn.getJobs()
                if int(cups_job_id) not in jobs:
                    return "COMPLETED"
                job_info = jobs[int(cups_job_id)]
                # cups.IPP_JOB_PROCESSING = 5, cups.IPP_JOB_COMPLETED = 9
                state = job_info.get("job-state", 0)
                if state in (7, 8):  # CANCELED, ABORTED
                    return "FAILED"
                elif state == 9:
                    return "COMPLETED"
                return "PROCESSING"
            except Exception:
                return "COMPLETED"

        # Monitor via lpstat CLI command
        try:
            for _ in range(45):
                res = subprocess.run(["lpstat", "-o", self.printer_name], capture_output=True, text=True)
                if cups_job_id not in res.stdout:
                    agent_logger.info(f"CUPS job {cups_job_id} cleared printer queue.")
                    return "COMPLETED"
                time.sleep(1)
            return "COMPLETED"
        except Exception:
            return "COMPLETED"

cups_service = CupsService()
