"""One authoritative capture path shared by checkout, webhooks and reconciliation."""
import hashlib
import json
import re
import uuid
from decimal import Decimal
from datetime import timedelta
from sqlalchemy.exc import IntegrityError
from app.config.settings import settings
from app.config.security import verify_razorpay_signature
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.document import Document, DocumentStatus
from app.db.models.security import WebhookEvent
from app.schemas.payment import PaymentCreateResponse
from app.services.gateway import gateway
from app.services.otp_service import otp_service
from app.utils.common import now, naive, fail, audit


def paise(amount):
    value = Decimal(str(amount)) * 100
    if not value.is_finite() or value != value.to_integral_value() or value <= 0:
        fail('INVALID_AMOUNT', 'Invalid stored payment amount.', 409)
    return int(value)


class PaymentService:
    def _response(self, payment):
        return PaymentCreateResponse(payment_id=payment.id, order_id=payment.order_id,
            razorpay_order_id=payment.razorpay_order_id, amount=float(payment.amount),
            amount_paise=paise(payment.amount), currency=payment.currency,
            key_id=payment.gateway_key_id)

    def _check_order(self, remote, order, payment, require_paid=False):
        if (remote.get('id') != payment.razorpay_order_id or
            remote.get('amount') != paise(order.amount) or
            remote.get('currency') != order.currency or
            remote.get('receipt') != order.id or
            remote.get('partial_payment') is True or
            payment.amount != order.amount or payment.currency != order.currency):
            fail('PAYMENT_MISMATCH', 'Provider order does not match the stored order.', 409)
        if require_paid and (remote.get('status') != 'paid' or
                remote.get('amount_paid') != paise(order.amount) or remote.get('amount_due') != 0):
            fail('PAYMENT_NOT_CAPTURED', 'Payment is not yet fully captured. Check status shortly.', 409)

    def create_payment(self, db, order_id, user_id=None):
        order = db.query(Order).filter_by(id=order_id).with_for_update().populate_existing().one()
        if order.status != OrderStatus.CREATED:
            fail('INVALID_STATE', 'This order cannot initiate another payment.', 409)
        payment = db.query(Payment).filter_by(order_id=order.id).with_for_update().populate_existing().first()
        if payment:
            if payment.gateway_key_id != settings.RAZORPAY_KEY_ID:
                fail('PAYMENT_CONFIGURATION_CHANGED', 'Payment requires operator reconciliation.', 409)
            if payment.razorpay_order_id and payment.creation_state == 'READY':
                return self._response(payment)
            fail('PAYMENT_RECONCILING', 'Payment initiation is being reconciled. Check status before retrying.', 409)
        payment = Payment(id='p_' + uuid.uuid4().hex, order_id=order.id, user_id=user_id,
            amount=order.amount, currency=order.currency, status=PaymentStatus.PENDING,
            creation_state='CREATING', gateway_key_id=settings.RAZORPAY_KEY_ID)
        db.add(payment)
        audit(db, 'PAYMENT_INITIATED', order.id)
        # Persist intent BEFORE network I/O. A timeout/crash must never create a second order.
        db.commit()
        try:
            remote = gateway.create_order(paise(order.amount), order.id)
            payment.razorpay_order_id = gateway.identifier(remote.get('id'), 'order')
            self._check_order(remote, order, payment)
            payment.creation_state = 'READY'
            db.commit()
        except Exception:
            db.rollback()
            payment = db.query(Payment).filter_by(order_id=order_id).one()
            payment.creation_state = 'UNKNOWN'
            payment.last_error = 'ORDER_CREATION_UNCONFIRMED'
            db.commit()
            raise
        return self._response(payment)

    def verify_or_confirm_payment(self, db, order_id, rzp_order_id=None, rzp_payment_id=None, rzp_signature=None):
        payment = db.query(Payment).filter_by(order_id=order_id).first()
        if not payment or not payment.razorpay_order_id or payment.creation_state != 'READY':
            fail('PAYMENT_NOT_CREATED', 'No provider payment order exists.', 409)
        if payment.gateway_key_id != settings.RAZORPAY_KEY_ID:
            fail('PAYMENT_CONFIGURATION_CHANGED', 'Payment requires operator reconciliation.', 409)
        if rzp_order_id != payment.razorpay_order_id:
            fail('PAYMENT_MISMATCH', 'Checkout order does not match this order.')
        gateway.identifier(rzp_payment_id, 'pay')
        # Use the DATABASE order id, never the browser's id, for the HMAC message.
        if not rzp_signature or not verify_razorpay_signature(
                (payment.razorpay_order_id + '|' + rzp_payment_id).encode(),
                rzp_signature, settings.RAZORPAY_KEY_SECRET):
            fail('INVALID_SIGNATURE', 'Invalid payment signature.')
        provider_order_id = payment.razorpay_order_id
        db.commit()
        remote = gateway.fetch_payment(rzp_payment_id)
        remote_order = gateway.fetch_order(provider_order_id)
        return self.accept_capture(db, order_id, remote, remote_order)

    def accept_capture(self, db, order_id, remote, remote_order):
        # Uniform lock order across payment, release, job and refund transactions.
        order = db.query(Order).filter_by(id=order_id).with_for_update().populate_existing().one()
        payment = db.query(Payment).filter_by(order_id=order_id).with_for_update().populate_existing().one()
        self._check_order(remote_order, order, payment, require_paid=True)
        payment_id = gateway.identifier(remote.get('id'), 'pay')
        if (remote.get('order_id') != payment.razorpay_order_id or
                type(remote.get('amount')) is not int or remote['amount'] != paise(order.amount) or
                remote.get('currency') != order.currency):
            fail('PAYMENT_MISMATCH', 'Provider payment does not match the stored amount, currency or order.', 409)
        if remote.get('status') != 'captured' or remote.get('captured') is not True:
            fail('PAYMENT_NOT_CAPTURED', 'Payment is not captured yet. Check status shortly.', 409)
        if remote.get('amount_refunded', 0) != 0:
            fail('PAYMENT_REFUNDED', 'A refunded payment cannot release a print job.', 409)
        if payment.status in (PaymentStatus.CAPTURED, PaymentStatus.REFUNDED):
            if payment.razorpay_payment_id != payment_id or not payment.verified_at:
                fail('PAYMENT_CONFLICT', 'Payment requires operator review.', 409)
            db.commit()
            return {'success': payment.status == PaymentStatus.CAPTURED,
                    'orderId': order.id, 'status': order.status.value}
        if order.status not in (OrderStatus.CREATED, OrderStatus.EXPIRED):
            fail('INVALID_STATE', 'Order cannot accept a payment in its current state.', 409)
        duplicate = db.query(Payment).filter(Payment.razorpay_payment_id == payment_id,
                                             Payment.id != payment.id).first()
        if duplicate:
            fail('PAYMENT_REUSED', 'Payment has already been assigned to another order.', 409)
        payment.razorpay_payment_id = payment_id
        payment.status = PaymentStatus.CAPTURED
        payment.verified_at = now()
        payment.reconciled_at = now()
        payment.last_error = None
        # Retain only proof metadata; never raw card/customer payment data.
        payment.raw_payload = {'id': payment_id, 'order_id': remote['order_id'],
            'amount': remote['amount'], 'currency': remote['currency'], 'status': 'captured'}
        doc = db.query(Document).filter_by(id=order.document_id).first()
        if (order.status == OrderStatus.EXPIRED or not doc or doc.status != DocumentStatus.ACTIVE or
                (doc.expires_at and naive(doc.expires_at) <= now())):
            order.status = OrderStatus.EXPIRED
            from app.services.refund_service import refund_service
            refund_service.enqueue(db, order, payment, 'Payment captured after document/order expiry')
        else:
            existing = db.query(PrintJob).filter_by(order_id=order.id).first()
            if existing:
                fail('JOB_CONFLICT', 'Unexpected existing job; operator review required.', 409)
            order.status = OrderStatus.WAITING_FOR_OTP
            db.add(PrintJob(id='job_' + uuid.uuid4().hex, order_id=order.id,
                server_id=order.print_server_id, status=PrintJobStatus.QUEUED))
            otp_service.generate_and_store_otp(db, order.id)
        audit(db, 'PAYMENT_CAPTURE_VERIFIED', order.id, payment_id=payment_id)
        db.commit()
        return {'success': True, 'orderId': order.id, 'status': order.status.value}

    def reconcile(self, db, order_id):
        payment = db.query(Payment).filter_by(order_id=order_id).first()
        order = db.query(Order).filter_by(id=order_id).first()
        if not payment or not order or payment.gateway_key_id != settings.RAZORPAY_KEY_ID:
            fail('RECONCILIATION_REVIEW', 'No payment for the current gateway credentials.', 409)
        if not payment.razorpay_order_id:
            if naive(payment.created_at) > now() - timedelta(seconds=30):
                return {'success': False, 'status': order.status.value}
            matches = [o for o in gateway.find_orders(order.id) if o.get('receipt') == order.id]
            if len(matches) != 1:
                payment.last_error = 'ORDER_CREATION_REQUIRES_REVIEW'
                payment.reconciled_at = now()
                db.commit()
                return {'success': False, 'status': order.status.value, 'reviewRequired': True}
            payment.razorpay_order_id = gateway.identifier(matches[0].get('id'), 'order')
            self._check_order(matches[0], order, payment)
            payment.creation_state = 'READY'
            db.commit()
        remote_order = gateway.fetch_order(payment.razorpay_order_id)
        self._check_order(remote_order, order, payment)
        for remote in gateway.order_payments(payment.razorpay_order_id):
            if remote.get('status') == 'captured' and remote.get('captured') is True:
                # Fetch independently rather than trusting a callback's entity.
                full = gateway.fetch_payment(remote['id'])
                return self.accept_capture(db, order_id, full, remote_order)
        payment.reconciled_at = now()
        db.commit()
        return {'success': False, 'orderId': order.id, 'status': order.status.value}

    def handle_webhook(self, db, raw_body, signature, event_id=None):
        if (not settings.RAZORPAY_WEBHOOK_SECRET or not signature or
                not verify_razorpay_signature(raw_body, signature, settings.RAZORPAY_WEBHOOK_SECRET)):
            fail('INVALID_SIGNATURE', 'Invalid webhook signature.')
        if not event_id or not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', event_id):
            fail('INVALID_EVENT_ID', 'A valid Razorpay event ID is required.')
        try:
            payload = json.loads(raw_body)
            event_type = payload['event']
            entity = payload.get('payload', {}).get('payment', {}).get('entity', {})
            refund = payload.get('payload', {}).get('refund', {}).get('entity', {})
            remote_order = payload.get('payload', {}).get('order', {}).get('entity', {})
            refs = {'payment_id': entity.get('id') or refund.get('payment_id'),
                    'order_id': entity.get('order_id') or remote_order.get('id'),
                    'refund_id': refund.get('id')}
            if not isinstance(event_type, str) or len(event_type) > 64:
                raise ValueError()
        except (ValueError, KeyError, TypeError, AttributeError):
            fail('INVALID_PAYLOAD', 'Malformed webhook payload.')
        digest = hashlib.sha256(raw_body).hexdigest()
        existing = db.get(WebhookEvent, event_id)
        if existing:
            if existing.body_hash != digest:
                fail('EVENT_CONFLICT', 'Event ID was reused with a different payload.', 409)
            return {'status': 'accepted'}
        supported = event_type in ('payment.captured', 'order.paid', 'payment.authorized',
            'payment.failed', 'refund.created', 'refund.processed', 'refund.failed', 'payment.refunded')
        event = WebhookEvent(id=event_id, body_hash=digest, event_type=event_type,
            references=refs, status='PENDING' if supported else 'IGNORED')
        try:
            db.add(event)
            db.commit()
        except IntegrityError:
            db.rollback()
            existing = db.get(WebhookEvent, event_id)
            if not existing or existing.body_hash != digest:
                fail('EVENT_CONFLICT', 'Conflicting webhook event.', 409)
        # Acknowledge only after the event is durable. Worker retries provider/DB failures.
        return {'status': 'accepted'}

payment_service = PaymentService()
