from typing import Tuple
from app.config import config
from app.utils.logging import agent_logger

class PrinterMonitor:
    def __init__(self):
        self.printer_name = config.PRINTER_NAME

    def get_printer_status(self) -> Tuple[str, str]:
        """
        Returns (printer_state, paper_state).
        In production with CUPS, queries printer IPP attributes.
        Fallback / default returns ('READY', 'AVAILABLE').
        """
        if config.MOCK_CUPS:
            return "READY", "AVAILABLE"
        try:
            # If pycups available, query printer attributes
            import cups
            conn = cups.Connection(host=config.CUPS_SERVER)
            printers = conn.getPrinters()
            if self.printer_name in printers:
                info = printers[self.printer_name]
                state = info.get("printer-state", 3) # 3: IDLE, 4: PROCESSING, 5: STOPPED
                printer_state = "READY" if state == 3 else ("BUSY" if state == 4 else "ERROR")
                return printer_state, "AVAILABLE"
        except Exception:
            pass

        return "ERROR", "UNKNOWN"

printer_monitor = PrinterMonitor()
