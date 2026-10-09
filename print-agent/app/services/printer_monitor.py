from typing import Tuple
from app.config import config


class PrinterMonitor:
    def __init__(self):
        self.printer_name = config.PRINTER_NAME

    def get_printer_status(self) -> Tuple[str, str]:
        if config.MOCK_CUPS:
            return "READY", "AVAILABLE"
        from app.services.cups_service import cups_service
        from app.services.printer_health import observe
        try:
            conn = cups_service.cups.Connection(host=config.CUPS_SERVER)
            printers = conn.getPrinters()
            candidates = [info for name, info in printers.items()
                          if (not self.printer_name or name == self.printer_name)
                          and cups_service.is_physical_uri(info.get("device-uri"))]
            states = [observe(info)[0] for info in candidates]
            state = next((s for s in states if s in ("READY", "BUSY")), states[0] if states else "OFFLINE")
            return state, "OUT_OF_PAPER" if state == "OUT_OF_PAPER" else "AVAILABLE" if state in ("READY", "BUSY") else "UNKNOWN"
        except Exception:
            return "OFFLINE", "UNKNOWN"


printer_monitor = PrinterMonitor()
