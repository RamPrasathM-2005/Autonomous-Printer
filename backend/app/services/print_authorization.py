"""Keep temporary unpaid test authorization separate from verified payments."""
from app.config.settings import settings
from app.db.models.payment import PaymentStatus
from app.utils.common import fail


def unpaid_test_enabled():
    return (settings.ALLOW_UNPAID_TEST_PRINTING
            and settings.ENVIRONMENT in ('development', 'test')
            and settings.RAZORPAY_KEY_ID.startswith('rzp_test_'))


def is_unpaid_test(order):
    # This marker is written only by the server. Order request schemas forbid it.
    return (order.print_settings or {}).get('unpaidTestPrint') is True


def require_print_authorization(order, payment):
    if is_unpaid_test(order):
        if not unpaid_test_enabled() or payment is not None:
            fail('TEST_PRINT_DISABLED', 'Unpaid test printing is unavailable.', 403)
        return
    if not payment or payment.status != PaymentStatus.CAPTURED or not payment.verified_at or payment.last_error:
        fail('PAYMENT_REQUIRED', 'A verified captured payment is required.', 409)
