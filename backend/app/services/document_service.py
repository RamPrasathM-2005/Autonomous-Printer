import uuid
from datetime import timedelta
from pathlib import Path
from sqlalchemy import func
from starlette.concurrency import run_in_threadpool
from app.config.settings import settings
from app.db.models.document import Document, DocumentStatus
from app.db.models.security import CustomerSession
from app.services.storage_service import storage_service
from app.services.document_processor import process_document
from app.utils.file_security import validate_file_content
from app.utils.crypto import compute_file_sha256
from app.utils.common import now, fail, audit

class DocumentService:
    async def process_and_save_upload(self, db, file, session_id=None, user_id=None):
        if not session_id:
            fail('UNAUTHENTICATED', 'A customer session is required.', 401)
        # Serialize a session's uploads and order creation to enforce quotas under concurrency.
        db.query(CustomerSession).filter_by(id=session_id).with_for_update().one()
        total = db.query(func.coalesce(func.sum(Document.file_size), 0)).filter(
            Document.session_id == session_id, Document.status != DocumentStatus.DELETED).scalar()
        budget = min(settings.MAX_UPLOAD_MB * 1024 * 1024,
                     settings.MAX_SESSION_STORAGE_MB * 1024 * 1024 - total)
        temp = storage_service.get_temp_dir() / (uuid.uuid4().hex + '.upload')
        key = None
        try:
            size = 0
            header = b''
            with temp.open('xb') as output:
                while chunk := await file.read(65536):
                    size += len(chunk)
                    if size > budget:
                        fail('FILE_TOO_LARGE', 'Upload exceeds the file or session storage limit.', 413)
                    if not header:
                        header = chunk[:4096]
                    output.write(chunk)
            name = (file.filename or 'document').replace('\\', '/').split('/')[-1]
            if not name or len(name) > 200 or any(ord(c) < 32 for c in name):
                fail('INVALID_FILENAME', 'Invalid document filename.')
            mime, extension = validate_file_content(header, name, file.content_type)
            pages = await run_in_threadpool(process_document, {'operation': 'inspect', 'path': str(temp),
                                      'mime': mime, 'max_pages': settings.MAX_DOCUMENT_PAGES})
            digest = compute_file_sha256(str(temp))
            doc_id = 'doc_' + uuid.uuid4().hex
            filename = uuid.uuid4().hex + extension
            key = f'documents/{session_id}/{filename}'
            storage_service.save_file_atomically(temp, key)
            doc = Document(id=doc_id, session_id=session_id, user_id=user_id,
                original_filename=name, stored_filename=filename, storage_key=key,
                mime_type=mime, file_size=size, sha256=digest, page_count=pages,
                status=DocumentStatus.ACTIVE, expires_at=now() + timedelta(hours=settings.DOCUMENT_TTL_HOURS))
            db.add(doc)
            audit(db, 'DOCUMENT_UPLOADED', doc_id, actor='CUSTOMER')
            db.commit()
            return doc
        except Exception:
            db.rollback()
            if key:
                storage_service.delete_file(key)
            raise
        finally:
            temp.unlink(missing_ok=True)
            await file.close()

document_service = DocumentService()
