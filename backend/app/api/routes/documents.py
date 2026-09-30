from fastapi import APIRouter, Depends, UploadFile, File, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.db.session import get_db
from app.services.access_service import current_session
from app.db.models.order import Order
from app.utils.common import fail
from app.db.models.document import Document, DocumentStatus
from app.schemas.document import DocumentUploadResponse, DocumentResponse
from app.schemas.common import MessageResponse
from app.services.document_service import document_service
from app.utils.errors import AppException

router = APIRouter(prefix="/api/documents", tags=["Documents"])

@router.post("/upload", response_model=DocumentUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_document(
    file: UploadFile = File(...),
    session=Depends(current_session),
    db: Session = Depends(get_db)
):
    """
    Upload scoped to an authenticated customer session.
    Users can upload documents directly to print via station OTP.
    """
    doc = await document_service.process_and_save_upload(
        db=db,
        file=file,
        session_id=session.id
    )
    return DocumentUploadResponse(
        documentId=doc.id,
        originalFilename=doc.original_filename,
        pages=doc.page_count,
        size=doc.file_size,
        status=doc.status
    )

@router.get("/{document_id}", response_model=DocumentResponse)
def get_document_details(
    document_id: str,
    session=Depends(current_session),
    db: Session = Depends(get_db)
):
    doc = db.query(Document).filter(Document.id == document_id, Document.session_id == session.id).first()

    if not doc or doc.status == DocumentStatus.DELETED:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Document not found."
        )

    return doc

@router.delete("/{document_id}", response_model=MessageResponse)
def delete_document(
    document_id: str,
    session=Depends(current_session),
    db: Session = Depends(get_db)
):
    doc = db.query(Document).filter(Document.id == document_id, Document.session_id == session.id).first()

    if not doc:
        raise AppException(
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND",
            message="Document not found."
        )

    if db.query(Order).filter_by(document_id=doc.id).first():
        fail('DOCUMENT_IN_USE', 'An order owns this print-ready document.', 409)
    doc.status = DocumentStatus.CLEANUP_PENDING
    db.commit()
    return MessageResponse(message="Document scheduled for deletion.")
