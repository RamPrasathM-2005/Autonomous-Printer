"""Run separately: python -m app.worker. State survives API/worker restarts."""
import logging
import time
from datetime import timedelta
from sqlalchemy import text, or_, func
from app.config.settings import settings
from app.config.database import engine, SessionLocal
from app.db.base import Base  # Register every foreign-key target in this standalone process.
from app.db.models.security import WebhookEvent, WorkerState, RateLimitBucket
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.refund import Refund, RefundStatus
from app.db.models.order import Order, OrderStatus
from app.db.models.otp import OTP
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.services.payment_service import payment_service
from app.services.refund_service import refund_service
from app.services.gateway import gateway
from app.utils.common import now, naive, audit

log = logging.getLogger('reconciliation')

def process_event(db, event):
    refs = event.references
    payment = None
    if refs.get('order_id'):
        payment = db.query(Payment).filter_by(razorpay_order_id=refs['order_id']).first()
    if not payment and refs.get('payment_id'):
        remote = gateway.fetch_payment(refs['payment_id'])
        payment = db.query(Payment).filter_by(razorpay_order_id=remote.get('order_id')).first()
    if not payment:
        # May race persistence of a provider order; leave retriable, don't discard.
        raise RuntimeError('PAYMENT_NOT_LINKED')
    if payment.gateway_key_id != settings.RAZORPAY_KEY_ID:
        raise RuntimeError('KEY_ROTATION_REVIEW')
    if event.event_type.startswith('refund.') or event.event_type == 'payment.refunded':
        if payment.razorpay_payment_id:
            remote = gateway.fetch_payment(payment.razorpay_payment_id)
            refund_service.reconcile_external(db, payment, remote)
        refund = db.query(Refund).filter_by(order_id=payment.order_id).first()
        if refund: refund_service.process(db, refund.id)
    elif event.event_type in ('payment.captured', 'order.paid', 'payment.authorized'):
        result = payment_service.reconcile(db, payment.order_id)
        if not result.get('success') and event.event_type != 'payment.authorized':
            raise RuntimeError('CAPTURE_NOT_CONFIRMED')
    # payment.failed is one failed attempt, not proof the whole order has failed.
    event = db.get(WebhookEvent, event.id)
    event.status = 'PROCESSED'
    event.processed_at = now()
    event.last_error = None
    db.commit()

def run_once():
    with SessionLocal() as db:
        event_ids = [e.id for e in db.query(WebhookEvent).filter(
            WebhookEvent.status == 'PENDING', WebhookEvent.next_attempt_at <= now()).order_by(WebhookEvent.created_at).limit(50)]
        for event_id in event_ids:
            try:
                process_event(db, db.get(WebhookEvent, event_id))
            except Exception as exc:
                db.rollback()
                event = db.get(WebhookEvent, event_id)
                event.attempts += 1
                event.last_error = getattr(exc, 'error_code', type(exc).__name__)
                event.next_attempt_at = now() + timedelta(seconds=min(3600, 10 * 2 ** min(event.attempts, 8)))
                db.commit()
                log.warning('Webhook %s pending: %s', event_id, event.last_error)
        cutoff = now() - timedelta(seconds=60)
        payment_ids = [p.id for p in db.query(Payment).filter(
            Payment.gateway_key_id == settings.RAZORPAY_KEY_ID,
            Payment.status.in_([PaymentStatus.PENDING, PaymentStatus.CAPTURED]),
            or_(Payment.reconciled_at == None, Payment.reconciled_at < cutoff)
        ).order_by(func.coalesce(Payment.reconciled_at, Payment.created_at)).limit(30)]
        for payment_id in payment_ids:
            try:
                payment = db.get(Payment, payment_id)
                if payment.status == PaymentStatus.CAPTURED and payment.razorpay_payment_id:
                    remote = gateway.fetch_payment(payment.razorpay_payment_id)
                    refund_service.reconcile_external(db, payment, remote)
                else:
                    payment_service.reconcile(db, payment.order_id)
            except Exception as exc:
                db.rollback()
                payment = db.get(Payment, payment_id)
                payment.last_error = getattr(exc, 'error_code', type(exc).__name__)
                payment.reconciled_at = now()
                db.commit()
                log.warning('Payment %s reconciliation pending: %s', payment.id, payment.last_error)
        # Expired paid release codes become durable refund requests; never reissue automatically.
        expired_ids = [o.order_id for o in db.query(OTP).filter(OTP.active == True, OTP.expires_at < now()).limit(100)]
        for order_id in expired_ids:
            order = db.query(Order).filter_by(id=order_id).with_for_update().populate_existing().one()
            otp = db.query(OTP).filter_by(order_id=order_id).with_for_update().populate_existing().one()
            if order.status == OrderStatus.WAITING_FOR_OTP and otp.active and naive(otp.expires_at) < now():
                otp.active = False
                order.status = OrderStatus.EXPIRED
                payment = db.query(Payment).filter_by(order_id=order_id).one()
                if payment.verified_at and payment.status == PaymentStatus.CAPTURED:
                    refund_service.enqueue(db, order, payment, 'Release code expired before printing')
            db.commit()
        refund_ids = [r.id for r in db.query(Refund).filter(Refund.status.in_(
            [RefundStatus.PENDING, RefundStatus.PROCESSING])).limit(50)]
        for refund_id in refund_ids:
            try: refund_service.process(db, refund_id)
            except Exception as exc:
                db.rollback()
                log.warning('Refund %s pending: %s', refund_id, getattr(exc, 'error_code', type(exc).__name__))
        from app.services.cleanup_service import cleanup_service
        cleanup_service.run_storage_cleanup(db)
        db.query(RateLimitBucket).filter(RateLimitBucket.expires_at < now()).delete()
        state = db.get(WorkerState, 'reconciliation')
        if not state:
            state = WorkerState(name='reconciliation')
            db.add(state)
        state.last_success_at = now()
        state.last_error = None
        db.commit()


def main():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
    # Hold a connection-scoped MySQL advisory lock for the life of this worker.
    with engine.connect() as lock:
        if engine.dialect.name == 'mysql':
            if lock.scalar(text("SELECT GET_LOCK('print_reconciliation_worker', 0)")) != 1:
                raise SystemExit('Another reconciliation worker is running.')
        while True:
            try:
                if engine.dialect.name == 'mysql':
                    if lock.scalar(text("SELECT IS_USED_LOCK('print_reconciliation_worker') = CONNECTION_ID()")) != 1:
                        raise SystemExit('Worker lost its advisory lock; restart under supervision.')
                run_once()
            except Exception:
                log.exception('Reconciliation pass failed')
            time.sleep(settings.RECONCILE_INTERVAL_SECONDS)

if __name__ == '__main__':
    main()
