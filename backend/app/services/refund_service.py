"""Durable full-refund outbox. Unknown submissions are reconciled, never blindly retried."""
import uuid
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.refund import Refund, RefundStatus
from app.db.models.otp import OTP
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.services.gateway import gateway
from app.utils.common import now, fail, audit

class RefundService:
    def enqueue(self, db, order, payment, reason):
        existing = db.query(Refund).filter_by(order_id=order.id).first()
        if existing: return existing
        if payment.status != PaymentStatus.CAPTURED or not payment.verified_at:
            fail('REFUND_NOT_ELIGIBLE', 'A verified captured payment is required.', 409)
        refund = Refund(id='ref_' + uuid.uuid4().hex, order_id=order.id, payment_id=payment.id,
            amount=payment.amount, reason=reason[:255], status=RefundStatus.PENDING)
        db.add(refund)
        otp = db.query(OTP).filter_by(order_id=order.id).first()
        if otp: otp.active = False
        audit(db, 'REFUND_REQUESTED', order.id, reason=reason[:255])
        db.flush()
        return refund

    def process_refund(self, db, order_id, reason='Print failed before submission'):
        order = db.query(Order).filter_by(id=order_id).with_for_update().populate_existing().one()
        from app.services.print_authorization import is_unpaid_test
        if is_unpaid_test(order):
            fail('REFUND_NOT_ELIGIBLE', 'No payment was taken for this test order.', 409)
        if order.status not in (OrderStatus.FAILED, OrderStatus.EXPIRED):
            fail('REFUND_NOT_ELIGIBLE', 'Refund requires a confirmed failed or expired order.', 409)
        payment = db.query(Payment).filter_by(order_id=order_id).with_for_update().populate_existing().one()
        refund = self.enqueue(db, order, payment, reason)
        db.commit()
        return refund

    def process(self, db, refund_id):
        from app.services.payment_service import paise
        snapshot = db.get(Refund, refund_id)
        order = db.query(Order).filter_by(id=snapshot.order_id).with_for_update().populate_existing().one()
        payment = db.query(Payment).filter_by(order_id=order.id).with_for_update().populate_existing().one()
        refund = db.query(Refund).filter_by(id=refund_id).with_for_update().populate_existing().one()
        if refund.status == RefundStatus.COMPLETED: return
        if not payment.verified_at or not payment.razorpay_payment_id:
            fail('REFUND_REVIEW', 'Unverified legacy payment cannot be automatically refunded.', 409)
        if refund.status == RefundStatus.PENDING:
            current = gateway.fetch_payment(payment.razorpay_payment_id)
            if (current.get('id') != payment.razorpay_payment_id or
                    current.get('amount') != paise(payment.amount) or current.get('currency') != payment.currency):
                fail('REFUND_MISMATCH', 'Provider payment does not match the refund.', 409)
            refunded = current.get('amount_refunded', 0)
            if refunded == paise(payment.amount):
                # A full dashboard refund can race our outbox; do not submit a second refund.
                refund.status = RefundStatus.COMPLETED
                refund.refund_completed_at = now()
                refund.error_message = None
                payment.status = PaymentStatus.REFUNDED
                if order.status in (OrderStatus.EXPIRED, OrderStatus.FAILED):
                    order.status = OrderStatus.REFUNDED
                audit(db, 'EXTERNAL_FULL_REFUND_CONFIRMED', order.id)
                db.commit()
                return
            if refunded:
                refund.status = RefundStatus.FAILED
                refund.error_message = 'PARTIAL_REFUND_OPERATOR_REVIEW'
                db.commit()
                return
            refund.status = RefundStatus.PROCESSING
            refund.error_message = 'SUBMISSION_PENDING'
            db.commit()  # Persist the single dispatch BEFORE crossing the network boundary.
            try:
                remote = gateway.create_refund(payment.razorpay_payment_id, paise(refund.amount), refund.id)
                self.apply(db, refund.id, remote)
            except Exception:
                db.rollback()
                record = db.get(Refund, refund_id)
                record.error_message = 'SUBMISSION_UNCONFIRMED_RECONCILE_REQUIRED'
                db.commit()
                raise
        elif refund.razorpay_refund_id:
            remote = gateway.fetch_refund(refund.razorpay_refund_id)
            self.apply(db, refund.id, remote)
        else:
            matches = [r for r in gateway.payment_refunds(payment.razorpay_payment_id)
                if r.get('receipt') == refund.id or
                    (isinstance(r.get('notes'), dict) and r['notes'].get('local_refund_id') == refund.id)]
            if len(matches) == 1:
                self.apply(db, refund.id, matches[0])
            else:
                refund.error_message = 'SUBMISSION_UNKNOWN_OPERATOR_REVIEW'
                db.commit()

    def apply(self, db, refund_id, remote):
        from app.services.payment_service import paise
        snapshot = db.get(Refund, refund_id)
        order = db.query(Order).filter_by(id=snapshot.order_id).with_for_update().populate_existing().one()
        payment = db.query(Payment).filter_by(order_id=order.id).with_for_update().populate_existing().one()
        refund = db.query(Refund).filter_by(id=refund_id).with_for_update().populate_existing().one()
        if (remote.get('payment_id') != payment.razorpay_payment_id or
                remote.get('amount') != paise(refund.amount) or remote.get('currency') != payment.currency):
            fail('REFUND_MISMATCH', 'Provider refund does not match the stored refund.', 409)
        remote_id = gateway.identifier(remote.get('id'), 'rfnd')
        if refund.razorpay_refund_id and refund.razorpay_refund_id != remote_id:
            fail('REFUND_MISMATCH', 'Conflicting refund identifiers.', 409)
        refund.razorpay_refund_id = remote_id
        if remote.get('status') == 'processed':
            refund.status = RefundStatus.COMPLETED
            refund.refund_completed_at = now()
            refund.error_message = None
            payment.status = PaymentStatus.REFUNDED
            if order.status in (OrderStatus.EXPIRED, OrderStatus.FAILED):
                order.status = OrderStatus.REFUNDED
            audit(db, 'REFUND_CONFIRMED', order.id, refund_id=remote_id)
        elif remote.get('status') == 'failed':
            refund.status = RefundStatus.FAILED
            refund.error_message = 'PROVIDER_REFUND_FAILED_OPERATOR_REVIEW'
        else:
            refund.status = RefundStatus.PROCESSING
            refund.error_message = None
        db.commit()

    def reconcile_external(self, db, payment, remote_payment):
        """Block unsubmitted fulfilment when the provider reports any refund."""
        from app.services.payment_service import paise
        order = db.query(Order).filter_by(id=payment.order_id).with_for_update().populate_existing().one()
        payment = db.query(Payment).filter_by(id=payment.id).with_for_update().populate_existing().one()
        if (remote_payment.get('id') != payment.razorpay_payment_id or
                remote_payment.get('order_id') != payment.razorpay_order_id or
                remote_payment.get('amount') != paise(payment.amount) or
                remote_payment.get('currency') != payment.currency):
            fail('PAYMENT_MISMATCH', 'Refund references another payment.', 409)
        if remote_payment.get('amount_refunded', 0) > 0 or remote_payment.get('status') == 'refunded':
            full = remote_payment.get('amount_refunded') == paise(payment.amount)
            payment.status = PaymentStatus.REFUNDED if full else payment.status
            payment.last_error = 'PROVIDER_REFUNDED' if full else 'PARTIAL_REFUND_OPERATOR_REVIEW'
            otp = db.query(OTP).filter_by(order_id=order.id).first()
            if otp: otp.active = False
            job = db.query(PrintJob).filter_by(order_id=order.id).first()
            if job and job.status in (PrintJobStatus.QUEUED, PrintJobStatus.RELEASED):
                job.status = PrintJobStatus.FINAL_FAILED
            if order.status in (OrderStatus.CREATED, OrderStatus.WAITING_FOR_OTP, OrderStatus.RELEASED):
                order.status = OrderStatus.REFUNDED if full else OrderStatus.FAILED
            audit(db, 'PROVIDER_REFUND_RECONCILED', order.id, full=full)
        elif payment.last_error in ('GATEWAY_UNAVAILABLE', 'ConnectionError', 'Timeout'):
            payment.last_error = None
        payment.reconciled_at = now()
        db.commit()

refund_service = RefundService()
