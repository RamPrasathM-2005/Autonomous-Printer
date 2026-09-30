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

    def submit_job(self, file_path, settings, allow_mock=False):
        options = self.build_cups_options(settings)
        if self.mock_mode:
            if not allow_mock:
                raise CupsException('Mock printing was not authorized by the backend')
            return 'mock-' + uuid.uuid4().hex
        if not self.has_pycups:
            raise CupsException('A real CUPS printer is required. No simulated fallback is permitted.')
        try:
            conn = self.cups.Connection(host=config.CUPS_SERVER)
            return str(conn.printFile(self.printer_name, str(file_path), 'Secure print job', options))
        except Exception:
            # Submission may have reached CUPS before the connection failed.
            raise CupsException('Printer submission outcome unknown; operator review required')

    def monitor_job(self, cups_job_id):
        if cups_job_id.startswith('mock-'):
            return 'COMPLETED' if self.mock_mode else 'UNKNOWN'
        if not self.has_pycups:
            return 'UNKNOWN'
        try:
            conn = self.cups.Connection(host=config.CUPS_SERVER)
            state = conn.getJobAttributes(int(cups_job_id)).get('job-state')
            if state == 9: return 'COMPLETED'
            if state in (7, 8): return 'FAILED'
            if state in (3, 4, 5, 6): return 'PROCESSING'
            return 'UNKNOWN'
        except Exception:
            # Missing/purged printer jobs do not prove physical completion.
            return 'UNKNOWN'

cups_service = CupsService()
