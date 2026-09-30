import io
import uuid
import hashlib
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from fastapi import status
from pypdf import PdfWriter, PdfReader
from PIL import Image

from app.db.models.order import Order, OrderStatus
from app.db.models.document import Document, DocumentStatus
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.schemas.order import OrderCreateRequest, OrderItemConfig, PrintSettingsSchema
from app.services.pricing_service import pricing_service
from app.services.storage_service import storage_service
from app.utils.errors import AppException

class OrderService:
    @staticmethod
    def create_order(db: Session, req: OrderCreateRequest, user_id: Optional[int] = None) -> Order:
        # Validate print server
        server = db.query(PrintServer).filter(PrintServer.id == req.printServerId).first()
        if not server:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                error_code="NOT_FOUND",
                message="Print server station not found."
            )

        if server.status == PrintServerStatus.DISABLED:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="PRINT_SERVER_DISABLED",
                message="This print server station is currently disabled."
            )

        if server.status == PrintServerStatus.OFFLINE:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="PRINT_SERVER_OFFLINE",
                message="This print server station is currently offline."
            )

        # Determine items to process
        items_to_process: List[OrderItemConfig] = []
        if req.items and len(req.items) > 0:
            items_to_process = req.items
        elif req.documentId:
            items_to_process = [
                OrderItemConfig(
                    documentId=req.documentId,
                    settings=req.settings or PrintSettingsSchema()
                )
            ]
        else:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="MISSING_DOCUMENT",
                message="No document provided in order request."
            )

        # Case 1: Single Document Order
        if len(items_to_process) == 1:
            item = items_to_process[0]
            query = db.query(Document).filter(Document.id == item.documentId)
            if user_id is not None:
                query = query.filter((Document.user_id == user_id) | (Document.user_id == None))
            document = query.first()

            if not document:
                raise AppException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    error_code="NOT_FOUND",
                    message="Document not found."
                )

            if document.status != DocumentStatus.ACTIVE:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="INVALID_STATE",
                    message=f"Document status is {document.status.value}, cannot be printed."
                )

            if document.expires_at:
                doc_expires = document.expires_at
                if doc_expires.tzinfo is None:
                    doc_expires = doc_expires.replace(tzinfo=timezone.utc)
                if doc_expires < datetime.now(timezone.utc):
                    raise AppException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        error_code="DOCUMENT_EXPIRED",
                        message="Document has expired."
                    )

            selected_pages = pricing_service.parse_and_validate_page_range(
                item.settings.pageRange,
                document.page_count
            )
            total_pages = len(selected_pages)

            amount = pricing_service.calculate_price(
                selected_pages_count=total_pages,
                copies=item.settings.copies,
                is_colour=item.settings.colour
            )

            order_id = f"ORD-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"

            order = Order(
                id=order_id,
                user_id=user_id,
                document_id=document.id,
                print_server_id=server.id,
                print_settings=item.settings.model_dump(by_alias=True),
                total_pages=total_pages,
                copies=item.settings.copies,
                amount=amount,
                currency="INR",
                status=OrderStatus.CREATED,
                created_at=datetime.now(timezone.utc)
            )
            db.add(order)
            db.commit()
            db.refresh(order)
            return order

        # Case 2: Multi-Document Order (Merge all documents and calculate total sum)
        total_amount = 0.0
        total_print_pages = 0
        documents_for_merge = []
        items_summary = []
        any_colour = False

        for item in items_to_process:
            query = db.query(Document).filter(Document.id == item.documentId)
            if user_id is not None:
                query = query.filter((Document.user_id == user_id) | (Document.user_id == None))
            doc = query.first()

            if not doc:
                raise AppException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    error_code="NOT_FOUND",
                    message=f"Document {item.documentId} not found."
                )

            if doc.status != DocumentStatus.ACTIVE:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="INVALID_STATE",
                    message=f"Document '{doc.original_filename}' is not active."
                )

            selected_pages = pricing_service.parse_and_validate_page_range(
                item.settings.pageRange,
                doc.page_count
            )
            item_pages = len(selected_pages)
            item_price = pricing_service.calculate_price(
                selected_pages_count=item_pages,
                copies=item.settings.copies,
                is_colour=item.settings.colour
            )

            total_amount += item_price
            total_print_pages += (item_pages * item.settings.copies)
            if item.settings.colour:
                any_colour = True

            doc_path = storage_service.resolve_storage_key(doc.storage_key)
            documents_for_merge.append({
                "path": doc_path,
                "pages": selected_pages,
                "copies": item.settings.copies,
                "is_image": doc.mime_type.startswith("image/") or doc_path.suffix.lower() in [".png", ".jpg", ".jpeg", ".webp"]
            })
            items_summary.append({
                "document_id": doc.id,
                "filename": doc.original_filename,
                "pages": item_pages,
                "copies": item.settings.copies,
                "colour": item.settings.colour,
                "amount": item_price
            })

        order_id = f"ORD-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"

        # Combine documents into single unified PDF for physical and autonomous kiosk printing
        combined_doc_id = f"DOC-COMBINED-{uuid.uuid4().hex[:8].upper()}"
        target_combined_rel = f"documents/combined_{order_id}.pdf"
        target_combined_path = storage_service.storage_root / target_combined_rel
        target_combined_path.parent.mkdir(parents=True, exist_ok=True)

        writer = PdfWriter()
        for doc_item in documents_for_merge:
            f_path = doc_item["path"]
            sel_pages = doc_item["pages"]
            copies = doc_item["copies"]
            for _ in range(copies):
                if doc_item["is_image"]:
                    with Image.open(f_path) as img:
                        rgb_img = img.convert("RGB")
                        buf = io.BytesIO()
                        rgb_img.save(buf, format="PDF")
                        buf.seek(0)
                        img_reader = PdfReader(buf)
                        for p in img_reader.pages:
                            writer.add_page(p)
                else:
                    reader = PdfReader(str(f_path))
                    t_pages = len(reader.pages)
                    pages_to_add = sel_pages if sel_pages else list(range(1, t_pages + 1))
                    for p_num in pages_to_add:
                        if 1 <= p_num <= t_pages:
                            writer.add_page(reader.pages[p_num - 1])

        with open(target_combined_path, "wb") as f_out:
            writer.write(f_out)

        file_bytes = target_combined_path.read_bytes()
        sha256 = hashlib.sha256(file_bytes).hexdigest()

        # Register merged document in DB
        merged_document = Document(
            id=combined_doc_id,
            user_id=user_id,
            original_filename=f"Combined_{len(items_to_process)}_Documents.pdf",
            stored_filename=f"combined_{order_id}.pdf",
            storage_key=target_combined_rel,
            mime_type="application/pdf",
            file_size=len(file_bytes),
            sha256=sha256,
            page_count=len(writer.pages),
            status=DocumentStatus.ACTIVE,
            created_at=datetime.now(timezone.utc)
        )
        db.add(merged_document)
        db.commit()

        # Save order with combined document and total amount
        combined_settings = req.settings.model_dump(by_alias=True) if req.settings else {}
        combined_settings["colour"] = any_colour
        combined_settings["copies"] = 1
        combined_settings["items"] = items_summary

        order = Order(
            id=order_id,
            user_id=user_id,
            document_id=merged_document.id,
            print_server_id=server.id,
            print_settings=combined_settings,
            total_pages=len(writer.pages),
            copies=1,
            amount=round(total_amount, 2),
            currency="INR",
            status=OrderStatus.CREATED,
            created_at=datetime.now(timezone.utc)
        )
        db.add(order)
        db.commit()
        db.refresh(order)
        return order

order_service = OrderService()
