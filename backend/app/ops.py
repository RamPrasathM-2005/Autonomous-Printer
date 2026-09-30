"""Read-only local operations report: python -m app.ops. Never prints credentials."""
import json
from datetime import timedelta
from sqlalchemy import or_
from app.config.database import SessionLocal
from app.db.base import Base  # Register all models.
from app.db.models.security import WorkerState, WebhookEvent
from app.db.models.payment import Payment
from app.db.models.refund import Refund, RefundStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.utils.common import now, naive


def report(db):
    worker = db.get(WorkerState, 'reconciliation')
    age = (now() - naive(worker.last_success_at)).total_seconds() if worker and worker.last_success_at else None
    return {
        'workerAgeSeconds': round(age) if age is not None else None,
        'workerHealthy': age is not None and age < 180,
        'pendingWebhooks': db.query(WebhookEvent).filter_by(status='PENDING').count(),
        'paymentReview': [{'orderId': p.order_id, 'reason': p.last_error}
            for p in db.query(Payment).filter(Payment.last_error != None).limit(100)],
        'refundReview': [{'orderId': r.order_id, 'status': r.status.value, 'reason': r.error_message}
            for r in db.query(Refund).filter(or_(Refund.error_message != None,
                Refund.status == RefundStatus.FAILED)).limit(100)],
        'stalledPrintJobs': [{'orderId': j.order_id, 'jobId': j.id, 'cupsJobId': j.cups_job_id}
            for j in db.query(PrintJob).filter(PrintJob.status == PrintJobStatus.PRINTING,
                PrintJob.claimed_at < now() - timedelta(minutes=15)).limit(100)],
    }


if __name__ == '__main__':
    with SessionLocal() as db:
        print(json.dumps(report(db), indent=2))
