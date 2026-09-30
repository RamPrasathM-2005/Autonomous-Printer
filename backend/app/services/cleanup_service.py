from datetime import timedelta
from sqlalchemy import or_
from app.db.models.document import Document, DocumentStatus
from app.db.models.order import Order, OrderStatus
from app.db.models.security import CustomerSession
from app.services.storage_service import storage_service
from app.utils.common import now

ACTIVE = [OrderStatus.CREATED, OrderStatus.PAID, OrderStatus.JOB_QUEUED,
          OrderStatus.WAITING_FOR_OTP, OrderStatus.RELEASED, OrderStatus.PRINTING]

class CleanupService:
    def run_storage_cleanup(self, db):
        ids = [d.id for d in db.query(Document).filter(Document.status != DocumentStatus.DELETED,
            or_(Document.status == DocumentStatus.CLEANUP_PENDING, Document.expires_at < now())).limit(100)]
        deleted = skipped = failed = 0
        for doc_id in ids:
            try:
                doc = db.get(Document, doc_id)
                if doc.session_id:
                    db.query(CustomerSession).filter_by(id=doc.session_id).with_for_update().one()
                doc = db.query(Document).filter_by(id=doc_id).with_for_update().populate_existing().one()
                # Unpaid expired orders are not allowed to pin files forever.
                db.query(Order).filter(Order.document_id == doc.id, Order.status == OrderStatus.CREATED,
                    Order.created_at < now() - timedelta(hours=24)).update({'status': OrderStatus.EXPIRED})
                if db.query(Order).filter(Order.document_id == doc.id, Order.status.in_(ACTIVE)).first():
                    skipped += 1
                    db.commit()
                    continue
                storage_service.delete_file(doc.storage_key)
                doc.status = DocumentStatus.DELETED
                doc.deleted_at = now()
                db.commit()
                deleted += 1
            except Exception:
                db.rollback()
                failed += 1
        return {'deleted_documents': deleted, 'skipped_active': skipped, 'failed_deletions': failed}

cleanup_service = CleanupService()
