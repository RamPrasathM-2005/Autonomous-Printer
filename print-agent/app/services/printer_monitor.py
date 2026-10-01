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
        try:
            # If pycups available, query printer attributes
            import cups
            conn = cups.Connection(host=config.CUPS_SERVER)
            printers = conn.getPrinters()
            if self.printer_name in printers:
                info = printers[self.printer_name]
                state = info.get("printer-state", 3) # 3: IDLE, 4: PROCESSING, 5: STOPPED

                # Query detailed attributes including reasons and messages
                attrs = conn.getPrinterAttributes(self.printer_name)
                reasons = [str(r).lower() for r in attrs.get("printer-state-reasons", [])]
                msg = str(attrs.get("printer-state-message") or "").lower()

                is_media_empty = any(
                    r in reasons for r in ["media-empty", "media-needed", "media-empty-warning", "media-empty-error", "input-tray-missing"]
                ) or ("out of paper" in msg or "tray empty" in msg or "load paper" in msg)

                paper_state = "OUT_OF_PAPER" if is_media_empty else "AVAILABLE"

                if is_media_empty:
                    printer_state = "OUT_OF_PAPER"
                elif any(r in reasons for r in ["media-jam", "door-open", "offline"]):
                    printer_state = "ERROR"
                elif state == 5:
                    printer_state = "STOPPED"
                elif state == 4:
                    printer_state = "BUSY"
                else:
                    printer_state = "READY"

                return printer_state, paper_state
        except Exception:
            pass

        return "READY", "AVAILABLE"

printer_monitor = PrinterMonitor()
