from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.order import Order
from app.db.models.document import Document
from app.schemas.print_server import HeartbeatRequest, HeartbeatResponse
from app.schemas.agent import AgentJobResponse, AgentReleaseRequest, AgentReleaseResponse, AgentJobStatusUpdate
from app.schemas.common import MessageResponse
from app.services.otp_service import otp_service
from app.services.job_service import job_service
from app.api.dependencies import get_authenticated_agent

router = APIRouter(prefix="/api/agent", tags=["Agent Operations"])

@router.post("/heartbeat", response_model=HeartbeatResponse)
def agent_heartbeat(
    req: HeartbeatRequest,
    server: PrintServer = Depends(get_authenticated_agent),
    db: Session = Depends(get_db)
):
    server.last_heartbeat = datetime.now(timezone.utc)
    server.printer_state = req.printerState
    server.paper_state = req.paperState
    if server.status != PrintServerStatus.DISABLED:
        server.status = PrintServerStatus.ONLINE
    db.commit()
    return HeartbeatResponse(status="OK", server_time=server.last_heartbeat)

@router.get("/jobs", response_model=List[AgentJobResponse])
def get_pending_jobs(
    server: PrintServer = Depends(get_authenticated_agent),
    db: Session = Depends(get_db)
):
    return job_service.get_pending_jobs_for_server(db, server.id)

@router.post("/release", response_model=AgentReleaseResponse)
def release_job_with_otp(
    req: AgentReleaseRequest,
    server: PrintServer = Depends(get_authenticated_agent),
    db: Session = Depends(get_db)
):
    job = otp_service.verify_and_release_job(
        db=db,
        server_id=server.id,
        plaintext_otp=req.otp
    )
    order = db.query(Order).filter(Order.id == job.order_id).first()
    doc = db.query(Document).filter(Document.id == order.document_id).first()

    return AgentReleaseResponse(
        job_id=job.id,
        order_id=order.id,
        status=job.status,
        storage_key=doc.storage_key,
        settings=order.print_settings
    )

@router.post("/jobs/{job_id}/status", response_model=MessageResponse)
def update_job_status(
    job_id: str,
    update: AgentJobStatusUpdate,
    server: PrintServer = Depends(get_authenticated_agent),
    db: Session = Depends(get_db)
):
    job_service.update_job_status(
        db=db,
        server_id=server.id,
        job_id=job_id,
        update=update
    )
    return MessageResponse(message="Job status updated successfully.")
