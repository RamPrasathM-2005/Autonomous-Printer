import uuid
from typing import Optional
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from fastapi import status

from app.db.models.order import Order, OrderStatus
from app.db.models.document import Document, DocumentStatus
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.schemas.order import OrderCreateRequest
from app.services.pricing_service import pricing_service
from app.utils.errors import AppException

class OrderService:
    @staticmethod
    def create_order(db: Session, req: OrderCreateRequest, user_id: Optional[int] = None) -> Order:
        # Validate document
        query = db.query(Document).filter(Document.id == req.documentId)
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

        # Validate page range against document pages
        selected_pages = pricing_service.parse_and_validate_page_range(
            req.settings.pageRange,
            document.page_count
        )
        total_pages = len(selected_pages)

        # Calculate price authoritatively on backend
        amount = pricing_service.calculate_price(
            selected_pages_count=total_pages,
            copies=req.settings.copies
        )

        order_id = f"ORD-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"

        order = Order(
            id=order_id,
            user_id=user_id,
            document_id=document.id,
            print_server_id=server.id,
            print_settings=req.settings.model_dump(by_alias=True),
            total_pages=total_pages,
            copies=req.settings.copies,
            amount=amount,
            currency="INR",
            status=OrderStatus.CREATED,
            created_at=datetime.now(timezone.utc)
        )
        db.add(order)
        db.commit()
        db.refresh(order)
        return order

order_service = OrderService()
