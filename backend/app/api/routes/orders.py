import uuid
from datetime import datetime, timezone
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, Header, status
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
    authorization: Optional[str] = Header(None),
    x_customer_session: Optional[str] = Header(None, alias="X-Customer-Session"),
    db: Session = Depends(get_db)
):
    """
    Public order creation - no login required.
    Creates an order for an uploaded document and calculates authoritative price.
    Stores session_token for persistent customer order recovery.
    """
    session_token = None
    if x_customer_session and x_customer_session.strip():
        session_token = x_customer_session.strip()
    elif authorization and authorization.lower().startswith("bearer "):
        session_token = authorization.split(" ", 1)[1].strip()

    user_id = None
    if session_token:
        from app.config.security import decode_token
        payload = decode_token(session_token)
        if payload and payload.get("sub"):
            try:
                user_id = int(payload["sub"])
            except (ValueError, TypeError):
                pass

    order = order_service.create_order(db=db, req=req, user_id=user_id, session_token=session_token)
    return OrderResponse(
        id=order.id,
        user_id=order.user_id,
        roll_number=order.roll_number,
        department=order.department,
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

@router.get("/my", response_model=List[OrderResponse])
def get_my_orders(
    authorization: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    if not authorization or not authorization.lower().startswith("bearer "):
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHENTICATED",
            message="Please log in to view your orders."
        )
    token = authorization.split(" ", 1)[1].strip()
    from app.config.security import decode_token
    payload = decode_token(token)
    if not payload or not payload.get("sub"):
        raise AppException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHENTICATED",
            message="Invalid or expired session."
        )
    user_id = int(payload["sub"])
    orders = order_service.get_orders_for_user(db=db, user_id=user_id)
    result = []
    for o in orders:
        release_code = None
        if o.status in [OrderStatus.WAITING_FOR_OTP, OrderStatus.PAID, OrderStatus.JOB_QUEUED]:
            try:
                plaintext, _, _ = otp_service.get_otp_for_order(db, o.id)
                release_code = plaintext
            except Exception:
                pass

        result.append(
            OrderResponse(
                id=o.id,
                user_id=o.user_id,
                roll_number=o.roll_number,
                department=o.department,
                document_id=o.document_id,
                print_server_id=o.print_server_id,
                print_settings=o.print_settings,
                total_pages=o.total_pages,
                copies=o.copies,
                amount=float(o.amount),
                currency=o.currency,
                status=o.status,
                releaseCode=release_code,
                created_at=o.created_at
            )
        )
    return result

@router.get("/active")
def get_active_order(
    order_id: Optional[str] = None,
    authorization: Optional[str] = Header(None),
    x_customer_session: Optional[str] = Header(None, alias="X-Customer-Session"),
    db: Session = Depends(get_db)
):
    """
    Authoritative single-source-of-truth order recovery check.
    Checks if an unfinished order exists for the given order_id or customer session.
    Returns the exact stage and data without regenerating payments or OTPs.
    """
    session_token = None
    if x_customer_session and x_customer_session.strip():
        session_token = x_customer_session.strip()
    elif authorization and authorization.lower().startswith("bearer "):
        session_token = authorization.split(" ", 1)[1].strip()

    user_id = None
    if session_token:
        try:
            from app.config.security import decode_token
            token_payload = decode_token(session_token)
            if token_payload and token_payload.get("sub"):
                user_id = int(token_payload["sub"])
        except Exception:
            pass

    order = None
    if order_id and order_id.strip():
        order = db.query(Order).filter(Order.id == order_id.strip()).first()

    # Search active order for logged-in user
    if not order and user_id:
        order = db.query(Order).filter(
            Order.user_id == user_id,
            Order.status.in_([
                OrderStatus.CREATED,
                OrderStatus.PAID,
                OrderStatus.JOB_QUEUED,
                OrderStatus.WAITING_FOR_OTP,
                OrderStatus.RELEASED,
                OrderStatus.PRINTING
            ])
        ).order_by(Order.created_at.desc()).first()

    if not order and session_token:
        # Search recent orders for this session token
        candidates = db.query(Order).order_by(Order.created_at.desc()).limit(25).all()
        for cand in candidates:
            c_cfg = dict(cand.print_settings or {})
            if c_cfg.get("session_token") == session_token:
                order = cand
                break

    if not order:
        return {
            "hasActiveOrder": False,
            "stage": "NONE",
            "canUploadNew": True,
            "order": None
        }

    job = db.query(PrintJob).filter(PrintJob.order_id == order.id).first()
    cur_settings = dict(order.print_settings or {})
    ord_resp = OrderResponse(
        id=order.id,
        user_id=order.user_id,
        roll_number=order.roll_number,
        department=order.department,
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

    if order.status == OrderStatus.CREATED:
        return {
            "hasActiveOrder": True,
            "stage": "UNPAID",
            "canUploadNew": True,
            "order": ord_resp
        }

    if order.status in [OrderStatus.PAID, OrderStatus.JOB_QUEUED, OrderStatus.WAITING_FOR_OTP]:
        # Ensure active OTP exists without changing it if already valid
        now = datetime.now(timezone.utc)
        active_otp = db.query(OTP).filter(OTP.order_id == order.id, OTP.active == True).first()
        if not active_otp or not cur_settings.get("printer_otps"):
            otp_service.generate_and_store_otp(db, order.id)
            order.status = OrderStatus.WAITING_FOR_OTP
            order.updated_at = now
            db.commit()

        plaintext, expires_at, printer_otps = otp_service.get_otp_for_order(db, order.id)
        ord_resp.releaseCode = plaintext
        selected_printer = cur_settings.get("cups_printer_name") or cur_settings.get("selected_printer")
        is_locked = cur_settings.get("printer_selection_locked", False)

        return {
            "hasActiveOrder": True,
            "stage": "WAITING_FOR_OTP",
            "canUploadNew": True,
            "selectedPrinter": selected_printer,
            "printerSelectionLocked": is_locked,
            "order": ord_resp,
            "otp": {
                "orderId": order.id,
                "otp": plaintext,
                "expiresAt": None,
                "printerOtps": printer_otps,
                "selectedPrinter": selected_printer,
                "printerSelectionLocked": is_locked
            }
        }

    if order.status in [OrderStatus.RELEASED, OrderStatus.PRINTING]:
        # Once accepted and printing starts, OTP is permanently invalid and never returned.
        return {
            "hasActiveOrder": True,
            "stage": "PRINTING",
            "canUploadNew": True,
            "selectedPrinter": cur_settings.get("cups_printer_name") or cur_settings.get("selected_printer"),
            "order": ord_resp
        }

    if order.status == OrderStatus.COMPLETED:
        # Order is completed and read-only. No longer recoverable as unfinished.
        return {
            "hasActiveOrder": False,
            "stage": "COMPLETED",
            "isCompletedReceipt": True,
            "canUploadNew": True,
            "selectedPrinter": cur_settings.get("cups_printer_name") or cur_settings.get("selected_printer"),
            "order": ord_resp
        }

    # FAILED, EXPIRED, REFUNDED
    return {
        "hasActiveOrder": False,
        "stage": "TERMINATED",
        "canUploadNew": True,
        "order": ord_resp
    }

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
        roll_number=order.roll_number,
        department=order.department,
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
    Permanent invalidation enforced: once printer accepts OTP and job begins,
    or once completed, OTP is permanently invalid and cannot be viewed or reused.
    """
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Order not found."
        )

    if order.status in [OrderStatus.RELEASED, OrderStatus.PRINTING, OrderStatus.COMPLETED]:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="OTP_INVALIDATED",
            message="OTP is permanently invalid once printing has begun or the order is completed."
        )

    if order.status in [OrderStatus.FAILED, OrderStatus.EXPIRED, OrderStatus.REFUNDED]:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="OTP_NOT_ACTIVE",
            message="Order is no longer active."
        )

    # Check if active OTP exists
    now = datetime.now(timezone.utc)
    active_otp = db.query(OTP).filter(OTP.order_id == order.id, OTP.active == True).first()

    # Rule: The OTP must remain valid until it is successfully used to release the print job.
    # Viewing the OTP, pressing Back, refreshing the browser, closing the application, or restarting
    # the phone must never invalidate the OTP or require another payment.
    cur_cfg = dict(order.print_settings or {})
    if not active_otp or not cur_cfg.get("printer_otps"):
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
        selected_printer=cur_settings.get("cups_printer_name") or cur_settings.get("selected_printer"),
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
        for k, v in potps.items():
            if isinstance(v, dict) and (v.get("cups_printer_name") == chosen_printer or v.get("printer_id") == chosen_printer):
                p_info = v
                break
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

@router.post("/{order_id}/cancel")
def cancel_order_endpoint(
    order_id: str,
    payload: Optional[Dict[str, Any]] = None,
    authorization: Optional[str] = Header(None),
    x_customer_session: Optional[str] = Header(None, alias="X-Customer-Session"),
    db: Session = Depends(get_db)
):
    session_token = None
    if x_customer_session and x_customer_session.strip():
        session_token = x_customer_session.strip()
    elif authorization and authorization.lower().startswith("bearer "):
        session_token = authorization.split(" ", 1)[1].strip()

    reason = (payload or {}).get("reason", "Customer cancelled order")
    return order_service.cancel_order(
        db=db,
        order_id=order_id,
        user_id=None,
        session_token=session_token,
        reason=reason
    )
