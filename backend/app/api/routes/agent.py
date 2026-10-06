from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.config.settings import settings
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.order import Order, OrderStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.document import Document
from app.schemas.print_server import HeartbeatRequest, HeartbeatResponse
from app.schemas.agent import AgentJobResponse, AgentReleaseRequest, AgentReleaseResponse, AgentJobStatusUpdate
from app.schemas.common import MessageResponse
from app.schemas.order import sanitize_print_settings
from app.services.otp_service import otp_service
from app.services.job_service import job_service
from app.api.dependencies import get_authenticated_agent

from app.db.models.printer import Printer
from app.db.models.discovered_printer import DiscoveredPrinter

router = APIRouter(prefix="/api/agent", tags=["Agent Operations"])

@router.post("/heartbeat", response_model=HeartbeatResponse)
def agent_heartbeat(
    req: HeartbeatRequest,
    server: PrintServer = Depends(get_authenticated_agent),
    db: Session = Depends(get_db)
):
    now = datetime.now(timezone.utc)
    server.last_heartbeat = now
    server.last_seen = now
    server.printer_state = req.printerState
    server.paper_state = req.paperState
    if server.status != PrintServerStatus.DISABLED:
        server.status = PrintServerStatus.ONLINE

    # Heartbeat printer synchronization & mismatch validation
    if req.printers is not None:
        registered_printers = db.query(Printer).filter(Printer.server_id == server.id).all()
        reported_by_name = {
            r.cups_printer_name.strip().lower(): r for r in req.printers if r.cups_printer_name
        }

        # 1. Check registered printers for mismatches or missing status
        for p in registered_printers:
            p_name_key = p.cups_printer_name.strip().lower()
            if p_name_key not in reported_by_name:
                p.has_mismatch = True
                p.mismatch_details = (
                    f"CUPS printer '{p.cups_printer_name}' not found on Print Agent"
                    if req.printers else "Printer not detected in CUPS (no connected printers reported)"
                )
                p.printer_status = "OFFLINE"
            else:
                rep = reported_by_name[p_name_key]
                # Compare static IP if both registered and reported have IP
                if p.ip_address and rep.ip_address and p.ip_address.strip() != rep.ip_address.strip():
                    p.has_mismatch = True
                    p.mismatch_details = (
                        f"IP Mismatch: Registered ({p.ip_address}) does not match reported ({rep.ip_address})"
                    )
                elif p.device_uri and rep.device_uri and p.device_uri.strip() != rep.device_uri.strip():
                    p.has_mismatch = True
                    p.mismatch_details = (
                        f"Device URI Mismatch: Registered ({p.device_uri}) does not match reported ({rep.device_uri})"
                    )
                else:
                    p.has_mismatch = False
                    p.mismatch_details = None

                p.printer_status = rep.status or "READY"
                p.job_count = rep.jobs or 0
                p.last_seen = now

        # 2. Track unregistered discovered printers without auto-modifying Printer table
        for rep in req.printers:
            if not rep.cups_printer_name:
                continue
            rep_key = rep.cups_printer_name.strip().lower()
            is_registered = any(p.cups_printer_name.strip().lower() == rep_key for p in registered_printers)
            if not is_registered:
                disc_id = f"{server.id}::{rep.cups_printer_name.strip()}"
                disc = db.query(DiscoveredPrinter).filter(DiscoveredPrinter.id == disc_id).first()
                if not disc:
                    disc = DiscoveredPrinter(
                        id=disc_id,
                        server_id=server.id,
                        cups_printer_name=rep.cups_printer_name.strip(),
                        ip_address=rep.ip_address,
                        device_uri=rep.device_uri,
                        reported_status=rep.status,
                        reported_jobs=str(rep.jobs or 0),
                        first_seen=now,
                        last_seen=now,
                    )
                    db.add(disc)
                else:
                    disc.ip_address = rep.ip_address or disc.ip_address
                    disc.device_uri = rep.device_uri or disc.device_uri
                    disc.reported_status = rep.status
                    disc.reported_jobs = str(rep.jobs or 0)
                    disc.last_seen = now

    db.commit()
    return HeartbeatResponse(status="OK", server_time=server.last_heartbeat)


@router.get("/jobs", response_model=List[AgentJobResponse])
def get_pending_jobs(
    server: PrintServer = Depends(get_authenticated_agent),
    db: Session = Depends(get_db)
):
    return job_service.get_pending_jobs_for_server(db, server.id)


@router.post("/release-kiosk")
def release_job_kiosk(
    req: AgentReleaseRequest,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Public endpoint for station touchscreen or mobile client.
    Verifies OTP with brute-force protection and triggers printing with internal agent authentication.
    """
    client_ip = request.client.host if request.client else "unknown"
    print(f"[BACKEND] Kiosk OTP release requested from {client_ip}.")
    job = otp_service.verify_and_release_job(
        db=db,
        server_id=None,
        plaintext_otp=req.otp,
        client_ip=client_ip
    )
    order = db.query(Order).filter(Order.id == job.order_id).first()
    doc = db.query(Document).filter(Document.id == order.document_id).first() if order else None

    # Job is now RELEASED in DB. Notify print agent immediately to print via CUPS with internal token
    payload = {
        "jobId": job.id,
        "orderId": order.id if order else "",
        "storageKey": doc.storage_key if doc else "",
        "settings": order.print_settings if order else {}
    }
    dispatch_headers = {
        "Authorization": f"Bearer {settings.INTERNAL_AGENT_TOKEN}",
        "X-Internal-Token": settings.INTERNAL_AGENT_TOKEN
    }
    for port in (5001, 5000):
        try:
            import requests
            resp = requests.post(
                f"http://127.0.0.1:{port}/local/print-job",
                json=payload,
                headers=dispatch_headers,
                timeout=3
            )
            if resp.status_code == 200:
                print(f"[KIOSK] Real print agent on {port} dispatched job {job.id} to physical printer.")
                break
            else:
                print(f"[KIOSK] Print agent on {port} responded with status: {resp.status_code}")
        except Exception as err:
            print(f"[KIOSK] Direct agent dispatch on port {port} warning: {err}")

    # Note: If direct HTTP dispatch was not reachable, job_poller polls every 3 seconds for RELEASED jobs.
    clean_settings = sanitize_print_settings(order.print_settings if order else {})
    return {
        "status": "RELEASED",
        "message": "OTP verified successfully. Printing started.",
        "jobId": job.id,
        "orderId": order.id if order else "",
        "fileName": doc.original_filename if doc else "Document.pdf",
        "storageKey": doc.storage_key if doc else "",
        "settings": clean_settings
    }

@router.post("/release", response_model=AgentReleaseResponse)
def release_job_with_otp(
    req: AgentReleaseRequest,
    request: Request,
    server: PrintServer = Depends(get_authenticated_agent),
    db: Session = Depends(get_db)
):
    client_ip = request.client.host if request.client else "unknown"
    job = otp_service.verify_and_release_job(
        db=db,
        server_id=server.id,
        plaintext_otp=req.otp,
        client_ip=client_ip
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
