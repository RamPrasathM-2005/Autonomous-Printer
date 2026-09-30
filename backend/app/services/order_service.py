import hashlib
import json
import uuid
from decimal import Decimal
from datetime import timedelta
from sqlalchemy import func
from app.config.settings import settings
from app.db.models.order import Order, OrderStatus
from app.db.models.document import Document, DocumentStatus
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer
from app.db.models.security import CustomerSession
from app.schemas.order import OrderItemConfig
from app.services.pricing_service import pricing_service
from app.services.storage_service import storage_service
from app.services.document_processor import process_document
from app.utils.crypto import compute_file_sha256
from app.utils.common import now, naive, fail, audit

class OrderService:
    def create_order(self, db, req, user_id=None, session_id=None, idempotency_key=None):
        if not session_id or not idempotency_key:
            fail('INVALID_REQUEST', 'Session and Idempotency-Key are required.')
        request_hash = hashlib.sha256(json.dumps(req.model_dump(), sort_keys=True).encode()).hexdigest()
        request_key = hashlib.sha256((session_id + ':' + idempotency_key).encode()).hexdigest()
        # Serializing by owner also enforces storage quotas and handles identical concurrent requests.
        db.query(CustomerSession).filter_by(id=session_id).with_for_update().populate_existing().one()
        previous = db.query(Order).filter_by(request_key=request_key).with_for_update().populate_existing().first()
        if previous:
            if previous.request_hash != request_hash:
                fail('IDEMPOTENCY_CONFLICT', 'Idempotency key already used for different print options.', 409)
            return previous
        station = db.query(PrintServer).filter_by(id=req.printServerId).first()
        if (not station or station.status != PrintServerStatus.ONLINE or not station.last_heartbeat or
                naive(station.last_heartbeat) < now() - timedelta(seconds=settings.HEARTBEAT_TIMEOUT_SECONDS) or
                station.printer_state != 'READY'):
            fail('STATION_UNAVAILABLE', 'Station is not ready. Try again when it is online.', 409)
        printer = db.query(Printer).filter_by(server_id=station.id, is_active=True).first()
        if not printer:
            fail('STATION_UNAVAILABLE', 'Station has no configured printer.', 409)
        items = req.items or ([OrderItemConfig(documentId=req.documentId, settings=req.settings)] if req.documentId else [])
        if not items:
            fail('MISSING_DOCUMENT', 'Select at least one document.')
        jobs, summary = [], []
        amount = settings.BASE_FEE
        pages_count = 0
        layout = None
        for item in items:
            doc = db.query(Document).filter_by(id=item.documentId, session_id=session_id).first()
            if not doc: fail('NOT_FOUND', 'Document not found.', 404)
            if doc.status != DocumentStatus.ACTIVE or (doc.expires_at and naive(doc.expires_at) <= now()):
                fail('DOCUMENT_EXPIRED', 'Document is unavailable or expired.', 409)
            opts = item.settings
            if opts.colour and not printer.supports_color:
                fail('UNSUPPORTED_OPTIONS', 'This printer does not support color.')
            if opts.sides != 'one-sided' and not printer.supports_duplex:
                fail('UNSUPPORTED_OPTIONS', 'This printer does not support duplex.')
            item_layout = (opts.sides, opts.paperSize, opts.orientation)
            if layout and layout != item_layout:
                fail('INCONSISTENT_LAYOUT', 'Documents in one job must use the same paper, orientation and sides.')
            layout = item_layout
            pages = pricing_service.parse_and_validate_page_range(opts.pageRange, doc.page_count)
            pages_count += len(pages) * opts.copies
            if pages_count > settings.MAX_ORDER_PAGES:
                fail('ORDER_TOO_LARGE', 'Too many printed pages in one order.')
            path = storage_service.resolve_storage_key(doc.storage_key)
            if not path.is_file() or compute_file_sha256(str(path)) != doc.sha256:
                fail('DOCUMENT_INTEGRITY', 'Stored document is missing or has changed.', 409)
            cost = pricing_service.calculate_price(len(pages), opts.copies, opts.colour, base_fee=0)
            amount += cost
            jobs.append({'path': str(path), 'pages': pages, 'copies': opts.copies, 'colour': opts.colour})
            summary.append({'document_id': doc.id, 'filename': doc.original_filename,
                'pages': len(pages), 'copies': opts.copies, 'colour': opts.colour, 'amount': str(cost)})
        # Receipt <= 40 chars. Full random identifiers prevent practical enumeration.
        order_id = 'ord_' + uuid.uuid4().hex
        temp = storage_service.get_temp_dir() / (uuid.uuid4().hex + '.pdf')
        key = 'documents/' + session_id + '/' + uuid.uuid4().hex + '.pdf'
        persisted = False
        try:
            count = process_document({'operation': 'render', 'items': jobs, 'output': str(temp)})
            if count != pages_count: fail('DOCUMENT_INTEGRITY', 'Rendered page count mismatch.', 409)
            size = temp.stat().st_size
            used = db.query(func.coalesce(func.sum(Document.file_size), 0)).filter(
                Document.session_id == session_id, Document.status != DocumentStatus.DELETED).scalar()
            if used + size > settings.MAX_SESSION_STORAGE_MB * 1024 * 1024:
                fail('STORAGE_QUOTA', 'Session storage quota exceeded.', 413)
            digest = compute_file_sha256(str(temp))
            storage_service.save_file_atomically(temp, key)
            persisted = True
            rendered = Document(id='doc_' + uuid.uuid4().hex, session_id=session_id,
                original_filename='Print-ready document.pdf', stored_filename=key.split('/')[-1],
                storage_key=key, mime_type='application/pdf', file_size=size,
                sha256=digest, page_count=count, status=DocumentStatus.ACTIVE,
                expires_at=now() + timedelta(hours=settings.DOCUMENT_TTL_HOURS))
            db.add(rendered)
            db.flush()
            # Copies/ranges/color conversion are baked into the immutable print-ready PDF.
            print_settings = {'copies': 1, 'pageRange': None, 'colour': any(i.settings.colour for i in items),
                'sides': layout[0], 'paperSize': layout[1], 'orientation': layout[2], 'items': summary}
            order = Order(id=order_id, session_id=session_id, request_key=request_key,
                request_hash=request_hash, document_id=rendered.id, print_server_id=station.id,
                print_settings=print_settings, total_pages=count, copies=1,
                amount=amount.quantize(Decimal('0.01')), currency='INR', status=OrderStatus.CREATED)
            db.add(order)
            audit(db, 'ORDER_PRICED', order_id, actor='CUSTOMER', amount=str(amount), sha256=digest)
            db.commit()
            return order
        except Exception:
            db.rollback()
            if persisted: storage_service.delete_file(key)
            raise
        finally:
            temp.unlink(missing_ok=True)

order_service = OrderService()
