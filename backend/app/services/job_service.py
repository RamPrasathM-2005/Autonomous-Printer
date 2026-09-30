import hmac
import secrets
from app.config.settings import settings
from app.config.security import hash_token
from app.db.models.order import Order, OrderStatus
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.document import Document, DocumentStatus
from app.services.refund_service import refund_service
from app.utils.common import now, fail, audit
from app.services.print_authorization import require_print_authorization, is_unpaid_test

class JobService:
    def get_pending_jobs_for_server(self, db, server_id):
        return [{'jobId': j.id, 'orderId': j.order_id} for j in db.query(PrintJob).filter_by(
            server_id=server_id, status=PrintJobStatus.RELEASED).order_by(PrintJob.created_at).limit(20)]

    def claim(self, db, server_id, job_id):
        snapshot = db.query(PrintJob).filter_by(id=job_id, server_id=server_id).first()
        if not snapshot: fail('NOT_FOUND', 'Job not found.', 404)
        order = db.query(Order).filter_by(id=snapshot.order_id).with_for_update().populate_existing().one()
        job = db.query(PrintJob).filter_by(id=job_id).with_for_update().populate_existing().one()
        payment = db.query(Payment).filter_by(order_id=order.id).with_for_update().populate_existing().first()
        if job.status != PrintJobStatus.RELEASED or order.status != OrderStatus.RELEASED or job.claim_token_hash:
            fail('JOB_ALREADY_CLAIMED', 'Job is no longer available for submission.', 409)
        require_print_authorization(order, payment)
        doc = db.query(Document).filter_by(id=order.document_id).one()
        token = secrets.token_urlsafe(32)
        job.claim_token_hash = hash_token(token)
        job.claimed_at = now()
        job.status = PrintJobStatus.PRINTING
        order.status = OrderStatus.PRINTING
        audit(db, 'JOB_CLAIMED', order.id, actor='AGENT', job_id=job.id)
        db.commit()
        return {'jobId': job.id, 'orderId': order.id, 'claimToken': token,
            'storageKey': doc.storage_key, 'sha256': doc.sha256, 'fileSize': doc.file_size,
            'settings': order.print_settings, 'allowMock': settings.ALLOW_MOCK_PRINTING and
                (is_unpaid_test(order) or bool(payment and payment.gateway_key_id and payment.gateway_key_id.startswith('rzp_test_')))}

    def update_job_status(self, db, server_id, job_id, update):
        snapshot = db.query(PrintJob).filter_by(id=job_id, server_id=server_id).first()
        if not snapshot: fail('NOT_FOUND', 'Job not found.', 404)
        order = db.query(Order).filter_by(id=snapshot.order_id).with_for_update().populate_existing().one()
        job = db.query(PrintJob).filter_by(id=job_id).with_for_update().populate_existing().one()
        if not job.claim_token_hash or not hmac.compare_digest(job.claim_token_hash, hash_token(update.claimToken)):
            fail('INVALID_CLAIM', 'Invalid job claim.', 403)
        if update.status == 'COMPLETED' and job.status == PrintJobStatus.COMPLETED:
            return job
        if update.status == 'FAILED' and job.status == PrintJobStatus.FINAL_FAILED:
            return job
        if job.status != PrintJobStatus.PRINTING or order.status != OrderStatus.PRINTING:
            fail('INVALID_STATE', 'Job is not processing.', 409)
        if update.cupsJobId:
            if job.cups_job_id and job.cups_job_id != update.cupsJobId:
                fail('CUPS_JOB_CONFLICT', 'Printer job identifier changed.', 409)
            job.cups_job_id = update.cupsJobId
        if update.status == 'COMPLETED':
            if not job.cups_job_id: fail('INVALID_STATE', 'Printer confirmation is required.', 409)
            if job.cups_job_id.startswith('mock-') and not settings.ALLOW_MOCK_PRINTING:
                fail('MOCK_FORBIDDEN', 'Simulated completion is disabled.', 409)
            job.status = PrintJobStatus.COMPLETED
            order.status = OrderStatus.COMPLETED
            order.print_settings = {**order.print_settings, 'mockPrinting': job.cups_job_id.startswith('mock-')}
            doc = db.get(Document, order.document_id)
            doc.status = DocumentStatus.CLEANUP_PENDING
            audit(db, 'PRINT_CONFIRMED', order.id, actor='AGENT', cups_job_id=job.cups_job_id)
        elif update.status == 'FAILED':
            job.error_code = update.errorCode
            job.error_message = update.message
            job.status = PrintJobStatus.FINAL_FAILED
            order.status = OrderStatus.FAILED
            audit(db, 'PRINT_FAILED', order.id, actor='AGENT', error=update.errorCode)
            # Only definitely pre-submission failures are safe to refund automatically.
            # Unknown submission/partial output requires operator review, never blind retry.
            if update.errorCode in ('FILE_INTEGRITY', 'PRINTER_UNAVAILABLE', 'MOCK_FORBIDDEN') and not job.cups_job_id:
                payment = db.query(Payment).filter_by(order_id=order.id).first()
                if payment and not is_unpaid_test(order):
                    refund_service.enqueue(db, order, payment, 'Print could not be submitted')
        db.commit()
        return job

job_service = JobService()
