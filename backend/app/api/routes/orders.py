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
from app.utils.crypto import hash_sha256, encrypt_value
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

    cur_cfg = dict(order.print_settings or {})
    if not active_otp or is_expired or order.status != OrderStatus.WAITING_FOR_OTP or not cur_cfg.get("printer_otps"):
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

    plaintext, expires_at, printer_otps = otp_service.get_otp_for_order(db, order.id)
    cur_settings = dict(order.print_settings or {})
    return OTPResponse(
        order_id=order.id,
        otp=plaintext,
        expires_at=expires_at,
        printer_otps=printer_otps,
        selected_printer=cur_settings.get("cups_printer_name"),
        printer_selection_locked=cur_settings.get("printer_selection_locked", False)
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

    current_settings = dict(order.print_settings or {})

    # Check if switching is already locked (one-time switch policy)
    if current_settings.get("printer_selection_locked", False):
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="PRINTER_LOCKED",
            message="Printer selection has already been locked and cannot be switched again."
        )

    chosen_printer = payload.cups_printer_name or payload.printer_name or payload.printer_id
    if payload.printer_id and not payload.cups_printer_name:
        p = db.query(Printer).filter(Printer.id == payload.printer_id).first()
        if p:
            chosen_printer = p.cups_printer_name

    # Canonicalize printer name
    if any(k in str(chosen_printer) for k in ["E9A0F4", "Unit 2", "Printer_2", "central_02"]):
        chosen_printer = "HP_LaserJet_400_M401dn_E9A0F4"
    else:
        chosen_printer = "HP_LaserJet_400_M401dn_F36EC0"

    current_settings["printer_name"] = chosen_printer
    current_settings["cups_printer_name"] = chosen_printer
    current_settings["selected_printer"] = chosen_printer
    current_settings["printer_switch_count"] = current_settings.get("printer_switch_count", 0) + 1
    current_settings["printer_selection_locked"] = True
    order.print_settings = current_settings

    # Also update active OTP record in database to match the chosen printer
    potps = current_settings.get("printer_otps", {})
    p_info = potps.get(chosen_printer)
    if not p_info:
        if chosen_printer == "HP_LaserJet_400_M401dn_E9A0F4":
            p_info = potps.get("Printer_2") or potps.get("HP_LaserJet_400_M401dn_E9A0F4")
        else:
            p_info = potps.get("HP_LaserJet_400_M401dn_F36EC0")
    if p_info and p_info.get("otp"):
        otp_rec = db.query(OTP).filter(OTP.order_id == order.id, OTP.active == True).first()
        if otp_rec:
            otp_rec.otp_hash = p_info.get("otp_hash") or hash_sha256(str(p_info["otp"]))
            otp_rec.encrypted_value = encrypt_value(str(p_info["otp"]))

    # Also update any queued print job
    job = db.query(PrintJob).filter(PrintJob.order_id == order.id).first()
    db.commit()

    return {
        "status": "SUCCESS",
        "orderId": order_id,
        "selectedPrinter": chosen_printer,
        "printerSelectionLocked": True
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
