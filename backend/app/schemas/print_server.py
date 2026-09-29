from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict
from app.db.models.print_server import PrintServerStatus

class PrinterResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    server_id: str
    cups_printer_name: str
    display_name: str
    supports_color: bool
    supports_duplex: bool
    is_active: bool

class PrintServerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    location: Optional[str] = None
    status: PrintServerStatus
    last_heartbeat: Optional[datetime] = None
    printer_state: Optional[str] = None
    paper_state: Optional[str] = None
    printers: List[PrinterResponse] = []

class HeartbeatRequest(BaseModel):
    printerState: str = "READY"
    paperState: str = "AVAILABLE"

    def __init__(self, **data):
        if "printer_state" in data and "printerState" not in data:
            data["printerState"] = data.pop("printer_state")
        if "paper_state" in data and "paperState" not in data:
            data["paperState"] = data.pop("paper_state")
        super().__init__(**data)

class HeartbeatResponse(BaseModel):
    status: str
    server_time: datetime
