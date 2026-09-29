from datetime import datetime, timezone, timedelta
from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.config.settings import settings
from app.db.session import get_db
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer
from app.schemas.print_server import PrintServerResponse, PrinterResponse
from app.utils.errors import AppException

router = APIRouter(prefix="/api/print-servers", tags=["Print Servers"])

def _update_server_offline_status(server: PrintServer, db: Session):
    """
    Offline Detection (Section 42):
    If last_heartbeat < current_time - configured_timeout,
    then print_server.status = OFFLINE
    """
    if server.status not in [PrintServerStatus.DISABLED, PrintServerStatus.MAINTENANCE]:
        timeout = timedelta(seconds=settings.HEARTBEAT_TIMEOUT_SECONDS)
        now = datetime.now(timezone.utc)
        if server.last_heartbeat:
            hb = server.last_heartbeat
            if hb.tzinfo is None:
                hb = hb.replace(tzinfo=timezone.utc)
            if hb < now - timeout:
                if server.status != PrintServerStatus.OFFLINE:
                    server.status = PrintServerStatus.OFFLINE
                    db.commit()
        else:
            if server.status != PrintServerStatus.OFFLINE:
                server.status = PrintServerStatus.OFFLINE
                db.commit()

@router.get("", response_model=List[PrintServerResponse])
def list_print_servers(db: Session = Depends(get_db)):
    servers = db.query(PrintServer).all()
    results = []
    for s in servers:
        _update_server_offline_status(s, db)
        printers = db.query(Printer).filter(Printer.server_id == s.id, Printer.is_active == True).all()
        results.append(PrintServerResponse(
            id=s.id,
            name=s.name,
            location=s.location,
            status=s.status,
            last_heartbeat=s.last_heartbeat,
            printer_state=s.printer_state,
            paper_state=s.paper_state,
            printers=[PrinterResponse.model_validate(p) for p in printers]
        ))
    return results

@router.get("/{server_id}", response_model=PrintServerResponse)
def get_print_server(server_id: str, db: Session = Depends(get_db)):
    s = db.query(PrintServer).filter(PrintServer.id == server_id).first()
    if not s:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Print server station not found."
        )

    _update_server_offline_status(s, db)
    printers = db.query(Printer).filter(Printer.server_id == s.id, Printer.is_active == True).all()
    return PrintServerResponse(
        id=s.id,
        name=s.name,
        location=s.location,
        status=s.status,
        last_heartbeat=s.last_heartbeat,
        printer_state=s.printer_state,
        paper_state=s.paper_state,
        printers=[PrinterResponse.model_validate(p) for p in printers]
    )
