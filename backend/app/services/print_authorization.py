"""Shared payment requirement for code access, release and job claim."""
from app.db.models.payment import PaymentStatus
from app.utils.common import fail


def require_print_authorization(order, payment):
    if not payment or payment.status != PaymentStatus.CAPTURED or not payment.verified_at or payment.last_error:
        fail('PAYMENT_REQUIRED', 'A verified captured payment is required.', 409)
