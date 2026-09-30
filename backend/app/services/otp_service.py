from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from fastapi import status

from app.config.settings import settings
from app.db.models.order import Order, OrderStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.otp import OTP
from app.db.models.document import Document
from app.utils.crypto import generate_secure_otp, hash_sha256, encrypt_value, decrypt_value
from app.utils.errors import AppException
from app.utils.state_machine import validate_order_transition, validate_job_transition

class OTPService:
    @staticmethod
    def generate_and_store_otp(db: Session, order_id: str) -> str:
        """
        Generates a 6-digit cryptographic OTP, hashes it, and stores in the DB.
        Returns the plaintext OTP so the user can see it once in the response.
        Plaintext is never logged or stored in cleartext.
        """
        # Deactivate any previous OTPs for this order
        existing = db.query(OTP).filter(OTP.order_id == order_id, OTP.active == True).all()
        for old in existing:
            old.active = False

        plaintext_otp = generate_secure_otp(6)
        hashed_otp = hash_sha256(plaintext_otp)
        encrypted_otp = encrypt_value(plaintext_otp)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_TTL_MINUTES)

        otp_record = OTP(
            order_id=order_id,
            otp_hash=hashed_otp,
            encrypted_value=encrypted_otp,
            expires_at=expires_at,
            attempt_count=0,
            used_at=None,
            active=True
        )
        db.add(otp_record)
        db.flush()
        return plaintext_otp

    @staticmethod
    def get_otp_for_order(db: Session, order_id: str) -> tuple[str, datetime]:
        otp_record = db.query(OTP).filter(
            OTP.order_id == order_id,
            OTP.active == True
        ).first()

        if not otp_record or not otp_record.encrypted_value:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                error_code="NOT_FOUND",
                message="No active OTP found for this order."
            )

        expires = otp_record.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < datetime.now(timezone.utc):
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="OTP_EXPIRED",
                message="OTP has expired."
            )

        plaintext = decrypt_value(otp_record.encrypted_value)
        return plaintext, otp_record.expires_at

    @staticmethod
    def verify_and_release_job(
        db: Session,
        server_id: str | None = None,
        plaintext_otp: str = ""
    ) -> PrintJob:
        """
        Transactional verification of OTP by print server or kiosk web interface.
        Protects against race conditions and brute force attempts.
        """
        hashed_input = hash_sha256(plaintext_otp.strip())

        # Find matching order/job for this specific OTP hash directly
        matching_candidates = (
            db.query(OTP, Order, PrintJob, Document)
            .join(Order, Order.id == OTP.order_id)
            .join(PrintJob, PrintJob.order_id == Order.id)
            .join(Document, Document.id == Order.document_id)
            .filter(OTP.otp_hash == hashed_input)
            .order_by(OTP.id.desc())
            .with_for_update()
            .all()
        )

        if not matching_candidates:
            if server_id:
                active_otp = (
                    db.query(OTP)
                    .join(Order, Order.id == OTP.order_id)
                    .join(PrintJob, PrintJob.order_id == Order.id)
                    .filter(PrintJob.server_id == server_id, OTP.active == True)
                    .order_by(OTP.id.desc())
                    .first()
                )
                if active_otp:
                    active_otp.attempt_count += 1
                    if active_otp.attempt_count >= settings.MAX_OTP_ATTEMPTS:
                        active_otp.active = False
                        db.commit()
                        raise AppException(
                            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                            error_code="TOO_MANY_ATTEMPTS",
                            message="Maximum OTP attempts exceeded. Please request a new OTP."
                        )
                    db.commit()
            db.commit()
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="INVALID_OTP",
                message="Invalid OTP code. Please verify the code displayed on your screen."
            )

        # Pick matching entry for this server if specified, otherwise latest
        matching_entry = None
        if server_id:
            for entry in matching_candidates:
                if entry[2].server_id == server_id:
                    matching_entry = entry
                    break
        if not matching_entry:
            matching_entry = matching_candidates[0]

        otp_rec, order_rec, job_rec, doc_rec = matching_entry

        if order_rec.status == OrderStatus.COMPLETED or job_rec.status == PrintJobStatus.COMPLETED:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="ALREADY_PRINTED",
                message="This order has already been printed."
            )

        # IDEMPOTENCY: If already released or printing, return successfully
        if order_rec.status in (OrderStatus.RELEASED, OrderStatus.PRINTING):
            return job_rec

        # Check attempts lockout
        if otp_rec.attempt_count >= settings.MAX_OTP_ATTEMPTS:
            otp_rec.active = False
            db.commit()
            raise AppException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                error_code="TOO_MANY_ATTEMPTS",
                message="Maximum OTP attempts exceeded. Please request a new OTP."
            )

        # Check expiration
        expires = otp_rec.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < datetime.now(timezone.utc):
            otp_rec.active = False
            order_rec.status = OrderStatus.EXPIRED
            db.commit()
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="OTP_EXPIRED",
                message="OTP has expired. Please place a new print request."
            )

        # Legal state transitions
        validate_order_transition(order_rec.status, OrderStatus.RELEASED)
        validate_job_transition(job_rec.status, PrintJobStatus.RELEASED)

        now = datetime.now(timezone.utc)
        otp_rec.used_at = now
        otp_rec.active = False

        order_rec.status = OrderStatus.RELEASED
        order_rec.updated_at = now

        job_rec.status = PrintJobStatus.RELEASED
        job_rec.updated_at = now

        db.commit()
        db.refresh(job_rec)
        return job_rec

otp_service = OTPService()
