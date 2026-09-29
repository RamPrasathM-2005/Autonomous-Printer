from typing import List, Optional
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.order import Order, OrderStatus
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

    if order.status != OrderStatus.WAITING_FOR_OTP:
        raise AppException(
            status_code=status.HTTP_400_BAD_REQUEST,
            error_code="INVALID_STATE",
            message=f"Order is in {order.status.value} status, not waiting for OTP release."
        )

    plaintext, expires_at = otp_service.get_otp_for_order(db, order.id)
    return OTPResponse(
        order_id=order.id,
        otp=plaintext,
        expires_at=expires_at
    )
