"""Background reconciliation worker for Autonomous Printer Platform."""
import logging
import time
from datetime import datetime, timezone
from sqlalchemy import text

from app.config.settings import settings
from app.config.database import engine, SessionLocal
from app.db.base import Base
from app.db.models.order import Order, OrderStatus
from app.db.models.otp import OTP
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.refund import Refund, RefundStatus
from app.services.cleanup_service import cleanup_service

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
log = logging.getLogger("reconciliation")

def reconcile_expired_otps(db):
    """Expire stale OTPs and transition orders to EXPIRED status."""
    now_utc = datetime.now(timezone.utc)
    expired_otps = db.query(OTP).filter(
        OTP.active == True,
        OTP.expires_at < now_utc
    ).limit(50).all()

    for otp in expired_otps:
        otp.active = False
        order = db.query(Order).filter(Order.id == otp.order_id).first()
        if order and order.status == OrderStatus.WAITING_FOR_OTP:
            order.status = OrderStatus.EXPIRED
            log.info("Expired OTP for order %s", order.id)
            # Check if refund is needed for captured payment on unprinted expired order
            payment = db.query(Payment).filter(Payment.order_id == order.id).first()
            if payment and payment.status == PaymentStatus.CAPTURED:
                existing_refund = db.query(Refund).filter(Refund.order_id == order.id).first()
                if not existing_refund:
                    refund = Refund(
                        order_id=order.id,
                        payment_id=payment.id,
                        amount=payment.amount,
                        reason="Release code expired before printing",
                        status=RefundStatus.PENDING
                    )
                    db.add(refund)
                    log.info("Enqueued refund for expired order %s", order.id)
    db.commit()

def run_once():
    """Execute a single pass of reconciliation and maintenance."""
    with SessionLocal() as db:
        try:
            reconcile_expired_otps(db)
        except Exception as exc:
            db.rollback()
            log.warning("OTP reconciliation pass failed: %s", exc)

        try:
            cleanup_service.run_storage_cleanup(db)
        except Exception as exc:
            db.rollback()
            log.warning("Storage cleanup pass failed: %s", exc)

def main():
    log.info("Starting reconciliation worker...")
    interval = getattr(settings, "RECONCILE_INTERVAL_SECONDS", 15)
    while True:
        try:
            run_once()
        except Exception:
            log.exception("Unexpected error in reconciliation loop")
        time.sleep(interval)

if __name__ == "__main__":
    main()
