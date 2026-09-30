"""Temporary opt-in test path; creates no payment, capture, or refund records."""
import uuid
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment
from app.db.models.document import Document, DocumentStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.services.print_authorization import unpaid_test_enabled, is_unpaid_test
from app.services.otp_service import otp_service
from app.services.storage_service import storage_service
from app.utils.common import fail, audit, now, naive
from app.utils.crypto import compute_file_sha256


def authorize_test_print(db, order_id):
    if not unpaid_test_enabled():
        fail('TEST_PRINT_DISABLED', 'Unpaid test printing is unavailable.', 403)
    # Same order lock as payment creation/release: concurrent requests cannot
    # start both a real payment and an unpaid test for the same order.
    order = db.query(Order).filter_by(id=order_id).with_for_update().populate_existing().one()
    payment = db.query(Payment).filter_by(order_id=order.id).with_for_update().populate_existing().first()
    if payment:
        fail('PAYMENT_ALREADY_STARTED', 'Payment already started. Use a new order for a test print.', 409)
    if is_unpaid_test(order):
        db.commit()
        return {'orderId': order.id, 'status': order.status.value, 'testPrint': True}
    if order.status != OrderStatus.CREATED:
        fail('INVALID_STATE', 'Order cannot start a test print.', 409)
    document = db.query(Document).filter_by(id=order.document_id).one()
    path = storage_service.resolve_storage_key(document.storage_key)
    if (document.status != DocumentStatus.ACTIVE or
            (document.expires_at and naive(document.expires_at) <= now()) or
            not path.is_file() or compute_file_sha256(str(path)) != document.sha256):
        fail('DOCUMENT_INTEGRITY', 'Print-ready document is unavailable.', 409)
    if db.query(PrintJob).filter_by(order_id=order.id).first():
        fail('JOB_CONFLICT', 'An existing print job requires review.', 409)
    order.print_settings = {**order.print_settings, 'unpaidTestPrint': True}
    order.status = OrderStatus.WAITING_FOR_OTP
    db.add(PrintJob(id='job_' + uuid.uuid4().hex, order_id=order.id,
                   server_id=order.print_server_id, status=PrintJobStatus.QUEUED))
    otp_service.generate_and_store_otp(db, order.id)
    audit(db, 'UNPAID_TEST_PRINT_AUTHORIZED', order.id, actor='CUSTOMER')
    db.commit()
    return {'orderId': order.id, 'status': order.status.value, 'testPrint': True}
