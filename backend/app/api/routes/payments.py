from fastapi import APIRouter, Depends, Request, Header, status
from sqlalchemy.orm import Session
from typing import Optional

from app.db.session import get_db
from app.schemas.payment import PaymentCreateRequest, PaymentCreateResponse
from app.services.payment_service import payment_service

router = APIRouter(prefix="/api/payments", tags=["Payments"])

@router.post("/create", response_model=PaymentCreateResponse, status_code=status.HTTP_201_CREATED)
def create_payment(
    req: PaymentCreateRequest,
    db: Session = Depends(get_db)
):
    """
    Public payment initiation - no login required.
    Initializes a Razorpay order for the requested print order.
    """
    return payment_service.create_payment(
        db=db,
        order_id=req.orderId,
        user_id=None
    )

@router.post("/webhook")
async def razorpay_webhook(
    request: Request,
    x_razorpay_signature: Optional[str] = Header(None, alias="X-Razorpay-Signature"),
    db: Session = Depends(get_db)
):
    raw_body = await request.body()
    result = payment_service.handle_webhook(
        db=db,
        raw_body=raw_body,
        signature=x_razorpay_signature
    )
    return result
