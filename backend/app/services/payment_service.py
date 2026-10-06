"""Gateway-backed checkout, capture verification and payment recovery."""
import json
import logging
import re
import uuid
from decimal import Decimal
from datetime import datetime, timezone

from app.config.settings import settings
from app.config.security import verify_razorpay_signature
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.schemas.payment import PaymentCreateResponse
from app.services.otp_service import otp_service
from app.utils.errors import AppException

logger = logging.getLogger(__name__)
GATEWAY_ORDER = re.compile(r"^order_[A-Za-z0-9]+$")
GATEWAY_PAYMENT = re.compile(r"^pay_[A-Za-z0-9]+$")
PAID_STATES = {OrderStatus.WAITING_FOR_OTP, OrderStatus.RELEASED,
               OrderStatus.PRINTING, OrderStatus.COMPLETED}


class PaymentService:
    @staticmethod
    def _gateway_client():
        if (not settings.RAZORPAY_KEY_SECRET or
                settings.RAZORPAY_KEY_ID in {"", "rzp_test_key_id", "test_key"}):
            raise AppException(503, "PAYMENTS_UNAVAILABLE", "Payment gateway is not configured. Contact the station.")
        import razorpay
        return razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))

    @staticmethod
    def _gateway_call(call, *args, **kwargs):
        try:
            return call(*args, timeout=10, **kwargs)
        except Exception as exc:
            logger.warning("Razorpay request failed (%s)", type(exc).__name__)
            raise AppException(502, "GATEWAY_UNAVAILABLE", "Could not connect to the payment gateway. Please try again shortly.") from exc

    @staticmethod
    def _response(order, payment):
        return PaymentCreateResponse(
            payment_id=payment.id, order_id=order.id,
            razorpay_order_id=payment.razorpay_order_id,
            amount=float(order.amount), amount_paise=int(Decimal(str(order.amount)) * 100),
            currency=order.currency, key_id=settings.RAZORPAY_KEY_ID,
        )

    @classmethod
    def create_payment(cls, db, order_id, user_id=None):
        order = db.query(Order).filter(Order.id == order_id).with_for_update().first()
        if not order or (user_id is not None and order.user_id not in (None, user_id)):
            raise AppException(404, "NOT_FOUND", "Order not found.")
        if order.status != OrderStatus.CREATED:
            raise AppException(400, "INVALID_STATE", "This order cannot start another payment. Check its status.")
        payment = db.query(Payment).filter(Payment.order_id == order_id).first()
        if payment and payment.status == PaymentStatus.REFUNDED:
            raise AppException(400, "PAYMENT_REFUNDED", "This payment has been refunded.")
        # Keep the same real gateway order on retry. Replace legacy invented IDs.
        if payment and GATEWAY_ORDER.fullmatch(payment.razorpay_order_id):
            if payment.status == PaymentStatus.CAPTURED:
                raise AppException(400, "PAYMENT_CONFLICT", "Payment is captured. Check order status.")
            return cls._response(order, payment)
        gateway = cls._gateway_client()
        amount = int(Decimal(str(order.amount)) * 100)
        if amount <= 0:
            raise AppException(400, "PAYMENT_MISMATCH", "Order amount must be greater than zero.")
        entity = cls._gateway_call(gateway.order.create, {
            "amount": amount, "currency": order.currency,
            "receipt": f"{order.id[:25]}_{uuid.uuid4().hex[:10]}",
            "notes": {"orderId": order.id},
        })
        if (not GATEWAY_ORDER.fullmatch(str(entity.get("id", ""))) or
                entity.get("amount") != amount or entity.get("currency") != order.currency):
            raise AppException(502, "PAYMENT_MISMATCH", "Payment gateway returned an invalid order.")
        if payment is None:
            payment = Payment(id=f"pay_{uuid.uuid4().hex[:12]}", order_id=order.id,
                              user_id=order.user_id, amount=order.amount, currency=order.currency)
            db.add(payment)
        payment.razorpay_order_id = entity["id"]
        payment.status = PaymentStatus.PENDING
        payment.updated_at = datetime.now(timezone.utc)
        db.commit()
        return cls._response(order, payment)

    @staticmethod
    def _fulfill(db, order, payment, entity, signature=None):
        if (entity.get("order_id") != payment.razorpay_order_id or
                entity.get("amount") != int(Decimal(str(order.amount)) * 100) or
                entity.get("currency") != order.currency or
                not GATEWAY_PAYMENT.fullmatch(str(entity.get("id", "")))):
            raise AppException(400, "PAYMENT_MISMATCH", "Payment does not match this order.")
        if entity.get("status") != "captured":
            raise AppException(409, "PAYMENT_NOT_CAPTURED", "Payment is not yet captured. Check payment status shortly.")
        if entity.get("amount_refunded", 0) or payment.status == PaymentStatus.REFUNDED:
            raise AppException(409, "PAYMENT_REFUNDED", "This payment has been refunded.")
        other = db.query(Payment).filter(Payment.razorpay_payment_id == entity["id"], Payment.id != payment.id).first()
        if other:
            raise AppException(409, "PAYMENT_REUSED", "Payment has already been used for another order.")
        if payment.status == PaymentStatus.CAPTURED:
            if payment.razorpay_payment_id != entity["id"]:
                raise AppException(409, "PAYMENT_CONFLICT", "This order already has a different payment.")
            if order.status in PAID_STATES:
                return {"success": True, "orderId": order.id, "status": order.status.value}
        if order.status not in {OrderStatus.CREATED, OrderStatus.PAID, OrderStatus.JOB_QUEUED}:
            raise AppException(409, "INVALID_STATE", "This order cannot be released. Contact the station about your payment.")
        payment.status = PaymentStatus.CAPTURED
        payment.razorpay_payment_id = entity["id"]
        payment.razorpay_signature = signature
        payment.raw_payload = entity
        payment.updated_at = datetime.now(timezone.utc)
        order.status = OrderStatus.JOB_QUEUED
        if not db.query(PrintJob).filter(PrintJob.order_id == order.id).first():
            db.add(PrintJob(id=f"job_{uuid.uuid4().hex[:12]}", order_id=order.id,
                            server_id=order.print_server_id, status=PrintJobStatus.QUEUED, retry_count=0))
        db.flush()
        otp_service.generate_and_store_otp(db, order.id)
        order.status = OrderStatus.WAITING_FOR_OTP
        order.updated_at = datetime.now(timezone.utc)
        db.commit()
        return {"success": True, "orderId": order.id, "status": order.status.value}

    @classmethod
    def verify_or_confirm_payment(cls, db, order_id, rzp_order_id=None, rzp_payment_id=None, rzp_signature=None):
        order = db.query(Order).filter(Order.id == order_id).with_for_update().first()
        if not order:
            raise AppException(404, "NOT_FOUND", "Order not found.")
        payment = db.query(Payment).filter(Payment.order_id == order_id).first()
        if not payment:
            raise AppException(400, "PAYMENT_NOT_CREATED", "Start checkout before verifying payment.")
        if rzp_order_id != payment.razorpay_order_id:
            raise AppException(400, "PAYMENT_MISMATCH", "Payment order does not match checkout.")
        if not GATEWAY_PAYMENT.fullmatch(str(rzp_payment_id or "")) or not rzp_signature:
            raise AppException(400, "INVALID_SIGNATURE", "Payment verification details are incomplete.")
        if not verify_razorpay_signature(f"{payment.razorpay_order_id}|{rzp_payment_id}".encode(),
                                        rzp_signature, settings.RAZORPAY_KEY_SECRET):
            raise AppException(400, "INVALID_SIGNATURE", "Payment signature could not be verified.")
        gateway = cls._gateway_client()
        entity = cls._gateway_call(gateway.payment.fetch, rzp_payment_id)
        if entity.get("id") != rzp_payment_id:
            raise AppException(400, "PAYMENT_MISMATCH", "Payment gateway returned a different payment.")
        return cls._fulfill(db, order, payment, entity, rzp_signature)

    @classmethod
    def reconcile_payment(cls, db, order_id):
        order = db.query(Order).filter(Order.id == order_id).with_for_update().first()
        if not order:
            raise AppException(404, "NOT_FOUND", "Order not found.")
        if order.status in PAID_STATES:
            return {"status": "SUCCESS", "orderStatus": order.status.value, "paid": True}
        payment = db.query(Payment).filter(Payment.order_id == order_id).first()
        if order.status not in {OrderStatus.CREATED, OrderStatus.PAID, OrderStatus.JOB_QUEUED} or not payment or not GATEWAY_ORDER.fullmatch(payment.razorpay_order_id):
            return {"status": "PENDING", "orderStatus": order.status.value, "paid": False}
        gateway = cls._gateway_client()
        result = cls._gateway_call(gateway.order.payments, payment.razorpay_order_id)
        for entity in result.get("items", []):
            if entity.get("status") == "captured":
                cls._fulfill(db, order, payment, entity)
                return {"status": "SUCCESS", "orderStatus": order.status.value, "paid": True}
        return {"status": "PENDING", "orderStatus": order.status.value, "paid": False}

    @classmethod
    def handle_webhook(cls, db, raw_body, signature):
        if (not signature or not settings.RAZORPAY_WEBHOOK_SECRET or
                not verify_razorpay_signature(raw_body, signature, settings.RAZORPAY_WEBHOOK_SECRET)):
            raise AppException(400, "INVALID_SIGNATURE", "Razorpay webhook signature verification failed.")
        try:
            payload = json.loads(raw_body)
            if payload.get("event") not in {"payment.captured", "order.paid"}:
                return {"status": "ignored"}
            entity = payload.get("payload", {}).get("payment", {}).get("entity", {})
            gateway_order = entity.get("order_id") or payload.get("payload", {}).get("order", {}).get("entity", {}).get("id")
        except (ValueError, AttributeError, TypeError):
            raise AppException(400, "INVALID_PAYLOAD", "Malformed webhook payload.")
        if not gateway_order:
            raise AppException(400, "INVALID_PAYLOAD", "Missing payment order in webhook.")
        payment = db.query(Payment).filter(Payment.razorpay_order_id == gateway_order).first()
        if not payment:
            return {"status": "ignored", "reason": "No corresponding payment found"}
        if not entity:
            result = cls.reconcile_payment(db, payment.order_id)
            return {"status": "success" if result["paid"] else "pending"}
        order = db.query(Order).filter(Order.id == payment.order_id).with_for_update().first()
        if not order:
            raise AppException(404, "NOT_FOUND", "Associated order not found.")
        cls._fulfill(db, order, payment, entity, signature)
        return {"status": "success", "orderId": order.id}


payment_service = PaymentService()
