from datetime import datetime, timezone
from typing import List, Dict, Any
from sqlalchemy.orm import Session
from fastapi import status

from app.config.settings import settings
from app.db.models.order import Order, OrderStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.document import Document, DocumentStatus
from app.schemas.agent import AgentJobResponse, AgentJobStatusUpdate
from app.services.refund_service import refund_service
from app.utils.errors import AppException
from app.utils.state_machine import validate_job_transition, validate_order_transition

class JobService:
    @staticmethod
    def get_pending_jobs_for_server(db: Session, server_id: str) -> List[AgentJobResponse]:
        """
        Returns all RELEASED jobs for the authenticated print server.
        """
        results = (
            db.query(PrintJob, Order, Document)
            .join(Order, Order.id == PrintJob.order_id)
            .join(Document, Document.id == Order.document_id)
            .filter(
                PrintJob.server_id == server_id,
                PrintJob.status == PrintJobStatus.RELEASED
            )
            .all()
        )

        job_responses = []
        for job, order, doc in results:
            job_responses.append(AgentJobResponse(
                job_id=job.id,
                order_id=order.id,
                storage_key=doc.storage_key,
                settings=order.print_settings
            ))
        return job_responses

    @staticmethod
    def update_job_status(
        db: Session,
        server_id: str,
        job_id: str,
        update: AgentJobStatusUpdate
    ) -> PrintJob:
        job = db.query(PrintJob).filter(
            PrintJob.id == job_id,
            PrintJob.server_id == server_id
        ).with_for_update().first()

        if not job:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                error_code="NOT_FOUND",
                message="Print job not found for this print server."
            )

        order = db.query(Order).filter(Order.id == job.order_id).with_for_update().first()
        if not order:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                error_code="NOT_FOUND",
                message="Associated order not found."
            )

        target_status = update.status
        validate_job_transition(job.status, target_status)

        now = datetime.now(timezone.utc)
        job.updated_at = now

        if target_status == PrintJobStatus.PRINTING:
            job.status = PrintJobStatus.PRINTING
            if update.cupsJobId:
                job.cups_job_id = update.cupsJobId
            if update.errorCode:
                job.error_code = update.errorCode
            if update.message:
                job.error_message = update.message
            if order.status == OrderStatus.RELEASED:
                validate_order_transition(order.status, OrderStatus.PRINTING)
                order.status = OrderStatus.PRINTING
                order.updated_at = now

        elif target_status == PrintJobStatus.COMPLETED:
            job.status = PrintJobStatus.COMPLETED
            job.error_code = None
            job.error_message = None
            if order.status in [OrderStatus.PRINTING, OrderStatus.RELEASED, OrderStatus.WAITING_FOR_OTP]:
                validate_order_transition(order.status, OrderStatus.COMPLETED)
                order.status = OrderStatus.COMPLETED
                order.updated_at = now

            # Document can now be marked CLEANUP_PENDING
            doc = db.query(Document).filter(Document.id == order.document_id).first()
            if doc and doc.status == DocumentStatus.ACTIVE:
                doc.status = DocumentStatus.CLEANUP_PENDING

        elif target_status == PrintJobStatus.FAILED:
            job.error_code = update.errorCode
            job.error_message = update.message

            if job.retry_count < settings.MAX_PRINT_RETRIES:
                job.retry_count += 1
                job.status = PrintJobStatus.QUEUED
            else:
                job.status = PrintJobStatus.FINAL_FAILED
                if order.status in [OrderStatus.RELEASED, OrderStatus.PRINTING]:
                    validate_order_transition(order.status, OrderStatus.FAILED)
                    order.status = OrderStatus.FAILED
                    order.updated_at = now

                # Trigger automatic refund for final failure
                try:
                    refund_service.process_refund(
                        db=db,
                        order_id=order.id,
                        reason=update.message or "Print failed after retries"
                    )
                except Exception:
                    # Log error, don't crash status reporting
                    pass

        db.commit()
        db.refresh(job)
        return job

job_service = JobService()
