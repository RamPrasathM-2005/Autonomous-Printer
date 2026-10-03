import uuid
from datetime import datetime, timezone
from decimal import Decimal
from sqlalchemy.orm import Session
from fastapi import status

from app.config.settings import settings
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.refund import Refund, RefundStatus
from app.utils.errors import AppException
from app.utils.state_machine import validate_order_transition, validate_refund_transition

class RefundService:
    @staticmethod
    def process_refund(db: Session, order_id: str, reason: str = "Print failed") -> Refund:
        # Check if refund already exists
        existing = db.query(Refund).filter(Refund.order_id == order_id).first()
        if existing and existing.status == RefundStatus.COMPLETED:
            return existing

        order = db.query(Order).filter(Order.id == order_id).with_for_update().first()
        if not order:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                error_code="NOT_FOUND",
                message="Order not found for refund."
            )

        payment = db.query(Payment).filter(Payment.order_id == order_id).first()
        if not payment or payment.status != PaymentStatus.CAPTURED:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="REFUND_NOT_ELIGIBLE",
                message="Payment is not captured or does not exist for this order."
            )

        if not existing:
            refund_id = f"ref_{uuid.uuid4().hex[:12]}"
            refund = Refund(
                id=refund_id,
                order_id=order.id,
                payment_id=payment.id,
                amount=order.amount,
                reason=reason,
                status=RefundStatus.PENDING,
                refund_requested_at=datetime.now(timezone.utc)
            )
            db.add(refund)
            db.flush()
        else:
            refund = existing

        # Process with Razorpay if payment_id exists
        validate_refund_transition(refund.status, RefundStatus.PROCESSING)
        refund.status = RefundStatus.PROCESSING
        db.flush()

        rzp_refund_id = f"rfnd_{uuid.uuid4().hex[:14]}"
        success = True

        is_test_payment = (
            payment.razorpay_payment_id.startswith("pay_test_")
            or payment.razorpay_payment_id.startswith("pay_simulated_")
            or settings.RAZORPAY_KEY_ID in ["rzp_test_key_id", "test_key"]
            or settings.RAZORPAY_KEY_ID.startswith("rzp_test_")
            or settings.ENVIRONMENT == "development"
        )

        if payment.razorpay_payment_id and not is_test_payment:
            try:
                import razorpay
                client = razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))
                amount_paise = int(Decimal(str(order.amount)) * 100)
                rzp_resp = client.payment.refund(payment.razorpay_payment_id, {
                    "amount": amount_paise,
                    "notes": {"reason": reason, "orderId": order.id}
                })
                rzp_refund_id = rzp_resp.get("id", rzp_refund_id)
            except Exception as e:
                success = False
                refund.status = RefundStatus.FAILED
                refund.error_message = str(e)
                db.commit()
                raise AppException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    error_code="REFUND_FAILED",
                    message=f"Razorpay refund processing failed: {str(e)}"
                )
        elif is_test_payment and payment.razorpay_payment_id:
            # Try real refund if key is provided, but don't fail test flow if test account has zero balance
            try:
                import razorpay
                client = razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))
                amount_paise = int(Decimal(str(order.amount)) * 100)
                rzp_resp = client.payment.refund(payment.razorpay_payment_id, {
                    "amount": amount_paise,
                    "notes": {"reason": reason, "orderId": order.id}
                })
                rzp_refund_id = rzp_resp.get("id", rzp_refund_id)
            except Exception as test_e:
                print(f"[TEST REFUND] Razorpay test refund notice: {test_e}. Simulating successful test refund.")
                rzp_refund_id = f"rfnd_test_{uuid.uuid4().hex[:12]}"

        if success:
            validate_refund_transition(refund.status, RefundStatus.COMPLETED)
            refund.status = RefundStatus.COMPLETED
            refund.razorpay_refund_id = rzp_refund_id
            refund.refund_completed_at = datetime.now(timezone.utc)

            payment.status = PaymentStatus.REFUNDED
            if order.status in [OrderStatus.FAILED, OrderStatus.EXPIRED, OrderStatus.CANCELLED]:
                validate_order_transition(order.status, OrderStatus.REFUNDED)
                order.status = OrderStatus.REFUNDED

            db.commit()
            db.refresh(refund)

        return refund

refund_service = RefundService()
