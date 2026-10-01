from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from fastapi import status

from app.config.settings import settings
from app.db.models.order import Order, OrderStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.otp import OTP
from app.db.models.document import Document
from app.db.models.payment import Payment, PaymentStatus
from app.utils.crypto import generate_secure_otp, hash_sha256, encrypt_value, decrypt_value
from app.utils.errors import AppException
from app.utils.state_machine import validate_order_transition, validate_job_transition

class OTPService:
    @staticmethod
    def generate_and_store_otp(db: Session, order_id: str) -> str:
        """
        Generates distinct 6-digit cryptographic OTPs for connected station printers,
        hashes them, stores the primary in the OTP table and both in order.print_settings.
        """
        # Deactivate any previous OTPs for this order
        existing = db.query(OTP).filter(OTP.order_id == order_id, OTP.active == True).all()
        for old in existing:
            old.active = False

        # Generate distinct OTPs for Printer 1 and Printer 2
        otp_p1 = generate_secure_otp(6)
        otp_p2 = generate_secure_otp(6)
        while otp_p2 == otp_p1:
            otp_p2 = generate_secure_otp(6)

        hashed_p1 = hash_sha256(otp_p1)
        encrypted_p1 = encrypt_value(otp_p1)
        hashed_p2 = hash_sha256(otp_p2)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_TTL_MINUTES)

        otp_record = OTP(
            order_id=order_id,
            otp_hash=hashed_p1,
            encrypted_value=encrypted_p1,
            expires_at=expires_at,
            attempt_count=0,
            used_at=None,
            active=True
        )
        db.add(otp_record)

        # Store dual printer OTP structure in Order.print_settings
        order = db.query(Order).filter(Order.id == order_id).first()
        if order:
            cur_settings = dict(order.print_settings or {})
            cur_settings["printer_otps"] = {
                "HP_LaserJet_400_M401dn_F36EC0": {
                    "printer_id": "printer_central_01",
                    "printer_name": "HP LaserJet 400 M401dn",
                    "cups_printer_name": "HP_LaserJet_400_M401dn_F36EC0",
                    "description": "High-Speed Laser • Duplex B&W",
                    "type": "B&W Laser",
                    "badge": "Central Station - Tray 1",
                    "otp": otp_p1,
                    "otp_hash": hashed_p1,
                    "active": True
                },
                "Printer_2": {
                    "printer_id": "printer_central_02",
                    "printer_name": "Secondary Station Printer",
                    "cups_printer_name": "Printer_2",
                    "description": "Standard Station Printer • Color Supported",
                    "type": "Color / Tray 2",
                    "badge": "Central Station - Tray 2",
                    "otp": otp_p2,
                    "otp_hash": hashed_p2,
                    "active": True
                }
            }
            if "cups_printer_name" not in cur_settings:
                cur_settings["cups_printer_name"] = "HP_LaserJet_400_M401dn_F36EC0"
            if "printer_name" not in cur_settings:
                cur_settings["printer_name"] = "HP_LaserJet_400_M401dn_F36EC0"
            if "printer_switch_count" not in cur_settings:
                cur_settings["printer_switch_count"] = 0
            if "printer_selection_locked" not in cur_settings:
                cur_settings["printer_selection_locked"] = False
            order.print_settings = cur_settings

        db.flush()
        return otp_p1

    @staticmethod
    def get_otp_for_order(db: Session, order_id: str) -> tuple[str, datetime, dict]:
        otp_record = db.query(OTP).filter(
            OTP.order_id == order_id,
            OTP.active == True
        ).first()

        order = db.query(Order).filter(Order.id == order_id).first()
        settings = dict(order.print_settings or {}) if order else {}
        printer_otps = settings.get("printer_otps", {})

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
        return plaintext, otp_record.expires_at, printer_otps

    @staticmethod
    def verify_and_release_job(
        db: Session,
        server_id: str | None = None,
        plaintext_otp: str = ""
    ) -> PrintJob:
        """
        Transactional verification of OTP by print server or kiosk web interface.
        Supports dual-printer OTPs: routes job to the selected printer based on
        which OTP was entered, and immediately invalidates both OTPs to prevent duplicate printing.
        """
        raw_otp = plaintext_otp.strip()
        hashed_input = hash_sha256(raw_otp)

        # 1. Search candidate by standard OTP table hash
        matching_entry = None
        matched_printer_name = None

        candidates = (
            db.query(OTP, Order, PrintJob, Document)
            .join(Order, Order.id == OTP.order_id)
            .join(PrintJob, PrintJob.order_id == Order.id)
            .join(Document, Document.id == Order.document_id)
            .filter(OTP.otp_hash == hashed_input)
            .order_by(OTP.id.desc())
            .with_for_update()
            .all()
        )

        if candidates:
            matching_entry = candidates[0]
            matched_printer_name = "HP_LaserJet_400_M401dn_F36EC0"

        # 2. If not matched in primary OTP row, check active orders' printer_otps dictionary
        if not matching_entry:
            recent_orders = (
                db.query(Order, PrintJob, Document)
                .join(PrintJob, PrintJob.order_id == Order.id)
                .join(Document, Document.id == Order.document_id)
                .filter(Order.status.in_([
                    OrderStatus.WAITING_FOR_OTP,
                    OrderStatus.RELEASED,
                    OrderStatus.PRINTING,
                    OrderStatus.COMPLETED
                ]))
                .order_by(Order.created_at.desc())
                .limit(50)
                .all()
            )

            for ord_row, jb_row, dc_row in recent_orders:
                cfg = dict(ord_row.print_settings or {})
                potps = cfg.get("printer_otps", {})
                for p_cups, p_info in potps.items():
                    if (p_info.get("otp") == raw_otp) or (p_info.get("otp_hash") == hashed_input):
                        # Found order matching this printer's OTP
                        matched_printer_name = p_cups
                        otp_rec = (
                            db.query(OTP)
                            .filter(OTP.order_id == ord_row.id)
                            .order_by(OTP.id.desc())
                            .first()
                        )
                        if not otp_rec:
                            otp_rec = OTP(
                                order_id=ord_row.id,
                                otp_hash=hashed_input,
                                expires_at=datetime.now(timezone.utc) + timedelta(minutes=1440),
                                active=True
                            )
                            db.add(otp_rec)
                            db.flush()
                        matching_entry = (otp_rec, ord_row, jb_row, dc_row)
                        break
                if matching_entry:
                    break

        if not matching_entry:
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
                            message="Maximum OTP attempts exceeded. Please generate/request a new OTP."
                        )
                    db.commit()
            db.commit()
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="INVALID_OTP",
                message="Invalid OTP. Please check the OTP and try again."
            )

        otp_rec, order_rec, job_rec, doc_rec = matching_entry

        # Crucial Anti-Duplicate Rule:
        # Check if already completed or released. If one OTP was already used, BOTH are expired!
        order_settings = dict(order_rec.print_settings or {})
        if (
            order_rec.status in [OrderStatus.COMPLETED, OrderStatus.PRINTING]
            or job_rec.status in [PrintJobStatus.COMPLETED, PrintJobStatus.PRINTING]
            or otp_rec.used_at is not None
            or order_settings.get("is_released") is True
        ):
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="ALREADY_PRINTED",
                message="This print job has already been printed. Both OTPs are expired."
            )

        # Idempotency for already released jobs
        if order_rec.status == OrderStatus.RELEASED and job_rec.status == PrintJobStatus.RELEASED:
            return job_rec

        # Verify payment completion
        if order_rec.status == OrderStatus.CREATED:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="PAYMENT_NOT_COMPLETED",
                message="Payment has not been completed for this order."
            )
        payment = db.query(Payment).filter(Payment.order_id == order_rec.id).first()
        if payment and payment.status != PaymentStatus.CAPTURED:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="PAYMENT_NOT_COMPLETED",
                message="Payment has not been completed for this order."
            )

        # Check attempts lockout
        if otp_rec.attempt_count >= settings.MAX_OTP_ATTEMPTS:
            otp_rec.active = False
            db.commit()
            raise AppException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                error_code="TOO_MANY_ATTEMPTS",
                message="Maximum OTP attempts exceeded. Please generate/request a new OTP."
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
                message="OTP Expired. Please generate/request a new OTP."
            )

        # Determine target printer for this job
        target_printer = matched_printer_name or order_settings.get("cups_printer_name") or "HP_LaserJet_400_M401dn_F36EC0"

        # Apply state transitions
        validate_order_transition(order_rec.status, OrderStatus.RELEASED)
        validate_job_transition(job_rec.status, PrintJobStatus.RELEASED)

        now = datetime.now(timezone.utc)

        # 1. Immediately invalidate the primary OTP record
        otp_rec.used_at = now
        otp_rec.active = False

        # 2. Invalidate all printer OTPs in order settings & lock printer selection
        order_settings["cups_printer_name"] = target_printer
        order_settings["printer_name"] = target_printer
        order_settings["selected_printer"] = target_printer
        order_settings["is_released"] = True
        order_settings["released_at"] = now.isoformat()
        order_settings["printer_selection_locked"] = True

        if "printer_otps" in order_settings:
            for pkey, pval in order_settings["printer_otps"].items():
                pval["active"] = False
                pval["used_at"] = now.isoformat()
                pval["used_by_this_printer"] = (pkey == target_printer)

        order_rec.print_settings = order_settings
        order_rec.status = OrderStatus.RELEASED
        order_rec.updated_at = now

        job_rec.status = PrintJobStatus.RELEASED
        job_rec.updated_at = now

        db.commit()
        db.refresh(job_rec)
        return job_rec

otp_service = OTPService()
