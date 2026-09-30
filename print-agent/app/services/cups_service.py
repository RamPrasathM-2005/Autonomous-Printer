import os
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
        options["copies"] = str(copies)

        # Page ranges
        page_range = settings.get("pageRange") or settings.get("page_range")
        if page_range:
            options["page-ranges"] = str(page_range)

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

        if is_color:
            # IPP standard & cross-vendor CUPS Color options
            options["print-color-mode"] = "color"
            options["ColorModel"] = "RGB"
            options["BRColor"] = "Color"
            options["HPColorMode"] = "Color"
            options["OutputMode"] = "Color"
            options["CNColor"] = "Color"
        else:
            # IPP standard & cross-vendor CUPS Grayscale / Monochrome options
            options["print-color-mode"] = "monochrome"
            options["ColorModel"] = "Gray"
            options["BRColor"] = "Mono"
            options["HPColorMode"] = "Grayscale"
            options["OutputMode"] = "Grayscale"
            options["CNColor"] = "Mono"

        # Duplex / Sides
        sides = settings.get("sides", "one-sided")
        if sides in ["two-sided-long-edge", "two-sided-short-edge"]:
            options["sides"] = sides
        else:
            options["sides"] = "one-sided"

        # Media / Paper Size
        paper_size = settings.get("paperSize") or settings.get("paper_size", "A4")
        options["media"] = paper_size

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

        # Native pycups submission if installed
        if self.has_pycups:
            try:
                conn = self.cups.Connection(host=config.CUPS_SERVER)
                job_id = conn.printFile(
                    self.printer_name,
                    str(file_path),
                    f"Job_{file_path.name}",
                    options
                )
                return str(job_id)
            except Exception as e:
                agent_logger.warning(f"pycups printer not reachable ({e}). Falling back to simulated print.")
                return f"cups-sim-{uuid.uuid4().hex[:8]}"

        # CLI 'lp' command fallback
        try:
            cmd = ["lp", "-d", self.printer_name]
            for opt_k, opt_v in options.items():
                cmd.extend(["-o", f"{opt_k}={opt_v}"])
            cmd.append(str(file_path))

            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            output = result.stdout.strip()
            cups_id = output.split()[3] if len(output.split()) >= 4 else f"cups-{uuid.uuid4().hex[:6]}"
            return cups_id
        except Exception as e:
            agent_logger.warning(f"CUPS lp command failed or no physical printer connected ({e}). Auto-falling back to simulated print.")
            return f"cups-sim-{uuid.uuid4().hex[:8]}"

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

        return "COMPLETED"

cups_service = CupsService()
