import uuid
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from pydantic import BaseModel
from app.db.models.printer import Printer
from app.db.session import get_db
from app.db.models.order import Order, OrderStatus
from app.db.models.otp import OTP
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.schemas.order import OrderCreateRequest, OrderResponse, OTPResponse
from app.services.order_service import order_service
from app.services.otp_service import otp_service
from app.utils.errors import AppException

router = APIRouter(prefix="/api/orders", tags=["Orders"])

@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(
    req: OrderCreateRequest,
    db: Session = Depends(get_db)
):
    """
    Public order creation - no login required.
    Creates an order for an uploaded document and calculates authoritative price.
    """
    order = order_service.create_order(db=db, req=req, user_id=None)
    return OrderResponse(
        id=order.id,
        user_id=order.user_id,
        document_id=order.document_id,
        print_server_id=order.print_server_id,
        print_settings=order.print_settings,
        total_pages=order.total_pages,
        copies=order.copies,
        amount=float(order.amount),
        currency=order.currency,
        status=order.status,
        created_at=order.created_at
    )

@router.get("", response_model=List[OrderResponse])
def list_orders(db: Session = Depends(get_db)):
    orders = db.query(Order).order_by(Order.created_at.desc()).limit(50).all()
    return [
        OrderResponse(
            id=o.id,
            user_id=o.user_id,
            document_id=o.document_id,
            print_server_id=o.print_server_id,
            print_settings=o.print_settings,
            total_pages=o.total_pages,
            copies=o.copies,
            amount=float(o.amount),
            currency=o.currency,
            status=o.status,
            created_at=o.created_at
        )
        for o in orders
    ]

@router.get("/{order_id}", response_model=OrderResponse)
def get_order(
    order_id: str,
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Order not found."
        )

    job = db.query(PrintJob).filter(PrintJob.order_id == order.id).first()
    return OrderResponse(
        id=order.id,
        user_id=order.user_id,
        document_id=order.document_id,
        print_server_id=order.print_server_id,
        print_settings=order.print_settings,
        total_pages=order.total_pages,
        copies=order.copies,
        amount=float(order.amount),
        currency=order.currency,
        status=order.status,
        error_code=job.error_code if job else None,
        error_message=job.error_message if job else None,
        created_at=order.created_at
    )

@router.get("/{order_id}/otp", response_model=OTPResponse)
def get_order_otp(
    order_id: str,
    db: Session = Depends(get_db)
):
    """
    Retrieves the 6-digit release OTP for an order that is WAITING_FOR_OTP.
    No login required - order ID is the token/handle.
    """
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Order not found."
        )

    # Check if active OTP exists and is unexpired; if not, generate a fresh one
    now = datetime.now(timezone.utc)
    active_otp = db.query(OTP).filter(OTP.order_id == order.id, OTP.active == True).first()
    is_expired = False
    if active_otp:
        exp = active_otp.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if exp < now:
            is_expired = True
            active_otp.active = False
            db.commit()

    if not active_otp or is_expired or order.status != OrderStatus.WAITING_FOR_OTP:
        # Provision print job if not already present
        existing_job = db.query(PrintJob).filter(PrintJob.order_id == order.id).first()
        if not existing_job:
            job_id = f"job_{uuid.uuid4().hex[:12]}"
            print_job = PrintJob(
                id=job_id,
                order_id=order.id,
                server_id=order.print_server_id,
                status=PrintJobStatus.QUEUED,
                retry_count=0,
                created_at=now
            )
            db.add(print_job)
            db.flush()

        otp_service.generate_and_store_otp(db, order.id)
        order.status = OrderStatus.WAITING_FOR_OTP
        order.updated_at = now
        db.commit()

    plaintext, expires_at = otp_service.get_otp_for_order(db, order.id)
    return OTPResponse(
        order_id=order.id,
        otp=plaintext,
        expires_at=expires_at
    )

class SelectPrinterRequest(BaseModel):
    cups_printer_name: Optional[str] = None
    printer_name: Optional[str] = None
    printer_id: Optional[str] = None

@router.post("/{order_id}/printer")
def select_order_printer(
    order_id: str,
    payload: SelectPrinterRequest,
    db: Session = Depends(get_db)
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Order not found."
        )

    chosen_printer = payload.cups_printer_name or payload.printer_name or payload.printer_id
    if payload.printer_id and not payload.cups_printer_name:
        p = db.query(Printer).filter(Printer.id == payload.printer_id).first()
        if p:
            chosen_printer = p.cups_printer_name

    current_settings = dict(order.print_settings or {})
    current_settings["printer_name"] = chosen_printer
    current_settings["cups_printer_name"] = chosen_printer
    order.print_settings = current_settings

    # Also update any queued print job
    job = db.query(PrintJob).filter(PrintJob.order_id == order.id).first()
    db.commit()

    return {
        "status": "SUCCESS",
        "orderId": order_id,
        "selectedPrinter": chosen_printer
    }

@router.post("/{order_id}/release")
def release_order_endpoint(
    order_id: str,
    payload: Dict[str, Any],
    db: Session = Depends(get_db)
):
    otp = str(payload.get("otp", "")).strip()
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Order not found."
        )
    job = otp_service.verify_and_release_job(
        db=db,
        server_id=order.print_server_id,
        plaintext_otp=otp
    )
    return {
        "status": "RELEASED",
        "orderId": order.id,
        "jobId": job.id
    }
