import secrets
import uuid
from datetime import datetime, timezone, timedelta
from typing import Tuple, Optional, Dict, Any
from sqlalchemy.orm import Session
from fastapi import status
from app.services.sms_service import sms_service
from app.services.email_service import email_service

from app.config.settings import settings
from app.config.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    hash_token,
    decode_token,
)
from app.db.models.user import User, UserRole
from app.db.models.refresh_token import RefreshToken
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    StudentRegisterRequest,
    StudentLoginRequest,
    UpdateProfileRequest,
)
from app.utils.errors import AppException

class AuthService:
    @staticmethod
    def register(db: Session, req: RegisterRequest) -> User:
        existing = db.query(User).filter(User.email == req.email.lower()).first()
        if existing:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="EMAIL_EXISTS",
                message="A user with this email address already exists."
            )

        if req.phone:
            existing_phone = db.query(User).filter(User.phone == req.phone).first()
            if existing_phone:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="PHONE_EXISTS",
                    message="A user with this phone number already exists."
                )

        user = User(
            email=req.email.lower(),
            phone=req.phone,
            full_name=req.full_name,
            password_hash=hash_password(req.password),
            role=UserRole.USER,
            is_active=True
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    _email_otps: Dict[str, Dict[str, Any]] = {}
    _phone_otps: Dict[str, Dict[str, Any]] = _email_otps

    @classmethod
    def send_email_otp(cls, db: Session, email: str, purpose: str = "login") -> str:
        clean_email = email.strip().lower()
        clean_purpose = (purpose or "login").lower().strip()

        # Check existing user registration status
        existing_user = db.query(User).filter(User.email == clean_email).first()

        if clean_purpose == "login":
            if not existing_user:
                raise AppException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    error_code="USER_NOT_FOUND",
                    message="No account found with this email address. Please sign up first."
                )
        elif clean_purpose == "signup":
            if existing_user:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="EMAIL_EXISTS",
                    message="An account with this email address already exists. Please sign in."
                )

        now = datetime.now(timezone.utc)
        record = cls._email_otps.get(clean_email)

        # Rate limit: max 3 requests within 5 minutes per email
        if record:
            window_start = record.get("window_start", now)
            if now - window_start < timedelta(minutes=5):
                if record.get("request_count", 0) >= 3:
                    raise AppException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        error_code="RATE_LIMIT_EXCEEDED",
                        message="Too many verification requests. Please wait a few minutes before trying again."
                    )
                record["request_count"] = record.get("request_count", 0) + 1
            else:
                record["window_start"] = now
                record["request_count"] = 1
        else:
            record = {"window_start": now, "request_count": 1}

        # Cryptographically secure 6-digit OTP
        otp = f"{secrets.randbelow(900000) + 100000}"
        record["otp"] = otp
        record["expires_at"] = now + timedelta(minutes=5)
        record["attempts"] = 0
        cls._email_otps[clean_email] = record

        # Dispatch via Gmail SMTP
        email_service.send_otp(clean_email, otp, clean_purpose)
        return otp

    @classmethod
    def verify_email_otp(cls, email: str, otp: str, consume: bool = True) -> bool:
        clean_email = email.strip().lower()
        clean_otp = str(otp).strip()

        # Automated test environment bypass only
        if settings.ENVIRONMENT == "test" and clean_otp == "123456":
            return True

        record = cls._email_otps.get(clean_email)
        if not record:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="OTP_NOT_FOUND",
                message="No verification code was requested for this email."
            )

        now = datetime.now(timezone.utc)
        if now > record.get("expires_at", now):
            cls._email_otps.pop(clean_email, None)
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="OTP_EXPIRED",
                message="The verification code has expired. Please request a new code."
            )

        if record.get("attempts", 0) >= 3:
            cls._email_otps.pop(clean_email, None)
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="MAX_ATTEMPTS_EXCEEDED",
                message="Maximum verification attempts exceeded. Please request a new code."
            )

        if record.get("otp") != clean_otp:
            record["attempts"] = record.get("attempts", 0) + 1
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="INVALID_OTP",
                message="Invalid verification code."
            )

        if consume:
            cls._email_otps.pop(clean_email, None)
        else:
            record["verified"] = True
        return True

    @staticmethod
    def _issue_tokens(db: Session, user: User) -> Tuple[User, str, str, int]:
        token_data = {"sub": str(user.id), "role": user.role.value, "jti": uuid.uuid4().hex}
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)

        hashed_refresh = hash_token(refresh_token)
        expires_at = datetime.now(timezone.utc) + timedelta(days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS)

        db_refresh = RefreshToken(
            user_id=user.id,
            token_hash=hashed_refresh,
            expires_at=expires_at,
            revoked=False
        )
        db.add(db_refresh)
        db.commit()

        expires_in = settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60
        return user, access_token, refresh_token, expires_in

    # Backwards compatibility wrappers
    @classmethod
    def send_phone_otp(cls, db: Session, phone: str, purpose: str = "login") -> str:
        clean_target = phone.strip()
        if "@" in clean_target:
            return cls.send_email_otp(db, clean_target, purpose)
        # Search if existing user has this phone number to get their email
        user = db.query(User).filter(User.phone == clean_target).first()
        if user and user.email:
            return cls.send_email_otp(db, user.email, purpose)
        # Fallback to email service / mock
        return cls.send_email_otp(db, clean_target, purpose)

    @classmethod
    def verify_phone_otp(cls, phone: str, otp: str) -> bool:
        clean_target = phone.strip()
        if "@" in clean_target:
            return cls.verify_email_otp(clean_target, otp)
        clean_otp = str(otp).strip()
        if settings.ENVIRONMENT == "test" and clean_otp == "123456":
            return True
        return cls.verify_email_otp(clean_target, otp)

    @classmethod
    def student_register(
        cls,
        db: Session,
        req: "StudentRegisterRequest"
    ) -> Tuple[User, str, str, int]:
        clean_email = req.email.strip().lower()
        cls.verify_email_otp(clean_email, req.otp)

        clean_roll = req.roll_number.strip().upper()

        if db.query(User).filter(User.email == clean_email).first():
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="EMAIL_EXISTS",
                message="An account with this email already exists. Please sign in."
            )

        if db.query(User).filter(User.roll_number == clean_roll).first():
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="ROLL_EXISTS",
                message="An account with this roll number already exists."
            )

        user = User(
            email=clean_email,
            phone=req.phone.strip() if req.phone else None,
            roll_number=clean_roll,
            full_name=req.full_name.strip(),
            department=req.department.strip(),
            role=UserRole.USER,
            is_active=True
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        return cls._issue_tokens(db, user)

    @classmethod
    def student_login(
        cls,
        db: Session,
        req: "StudentLoginRequest"
    ) -> Tuple[User, str, str, int]:
        target_email = (req.email or req.phone or "").strip().lower()
        if not target_email:
            raise AppException(
                status_code=status.HTTP_400_BAD_REQUEST,
                error_code="EMAIL_REQUIRED",
                message="Email address is required."
            )

        cls.verify_email_otp(target_email, req.otp)

        user = db.query(User).filter(User.email == target_email).first()
        if not user and req.phone:
            user = db.query(User).filter(User.phone == req.phone.strip()).first()

        if not user:
            raise AppException(
                status_code=status.HTTP_404_NOT_FOUND,
                error_code="USER_NOT_FOUND",
                message="No account found with this email. Please sign up first."
            )

        if not user.is_active:
            raise AppException(
                status_code=status.HTTP_403_FORBIDDEN,
                error_code="USER_INACTIVE",
                message="Account has been deactivated."
            )

        return cls._issue_tokens(db, user)

    @staticmethod
    def update_profile(
        db: Session,
        user: User,
        req: "UpdateProfileRequest"
    ) -> User:
        if req.full_name is not None and req.full_name.strip():
            user.full_name = req.full_name.strip()
        if req.department is not None and req.department.strip():
            user.department = req.department.strip()
        if req.email is not None and req.email.strip() and req.email.strip().lower() != (user.email or "").lower():
            clean_email = req.email.strip().lower()
            existing = db.query(User).filter(User.email == clean_email, User.id != user.id).first()
            if existing:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="EMAIL_EXISTS",
                    message="This email is already associated with another account."
                )
            user.email = clean_email
        if req.phone is not None and req.phone.strip() and req.phone.strip() != user.phone:
            existing_phone = db.query(User).filter(User.phone == req.phone.strip(), User.id != user.id).first()
            if existing_phone:
                raise AppException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    error_code="PHONE_EXISTS",
                    message="Phone number is already associated with another account."
                )
            user.phone = req.phone.strip()
        db.commit()
        db.refresh(user)
        return user

    @classmethod
    def login(cls, db: Session, req: LoginRequest, admin_only: bool = False) -> Tuple[User, str, str, int]:
        user = db.query(User).filter(User.email == req.email.lower()).first()
        if not user or not user.password_hash or not verify_password(req.password, user.password_hash):
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                error_code="UNAUTHENTICATED",
                message="Invalid email or password."
            )

        if not user.is_active:
            raise AppException(
                status_code=status.HTTP_403_FORBIDDEN,
                error_code="USER_INACTIVE",
                message="Account has been deactivated."
            )

        if admin_only and user.role not in (UserRole.ADMIN, UserRole.SUPER_ADMIN):
            raise AppException(
                status_code=status.HTTP_403_FORBIDDEN,
                error_code="FORBIDDEN",
                message="Administrator privileges required."
            )

        return cls._issue_tokens(db, user)

    @staticmethod
    def refresh_access_token(db: Session, refresh_token_str: str) -> Tuple[str, int]:
        payload = decode_token(refresh_token_str)
        if not payload or payload.get("type") != "refresh":
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                error_code="INVALID_TOKEN",
                message="Invalid or expired refresh token."
            )

        hashed_token = hash_token(refresh_token_str)
        db_token = db.query(RefreshToken).filter(
            RefreshToken.token_hash == hashed_token,
            RefreshToken.revoked == False
        ).first()

        if not db_token:
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                error_code="INVALID_TOKEN",
                message="Refresh token has been revoked or is invalid."
            )

        # Compare dates with timezone awareness
        db_token_expires = db_token.expires_at
        if db_token_expires.tzinfo is None:
            db_token_expires = db_token_expires.replace(tzinfo=timezone.utc)

        if db_token_expires < datetime.now(timezone.utc):
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                error_code="TOKEN_EXPIRED",
                message="Refresh token has expired."
            )

        user = db.query(User).filter(User.id == db_token.user_id).first()
        if not user or not user.is_active:
            raise AppException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                error_code="UNAUTHENTICATED",
                message="User not found or inactive."
            )

        new_access_token = create_access_token({"sub": str(user.id), "role": user.role.value})
        expires_in = settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60
        return new_access_token, expires_in

    @staticmethod
    def logout(db: Session, refresh_token_str: str):
        hashed_token = hash_token(refresh_token_str)
        db_token = db.query(RefreshToken).filter(RefreshToken.token_hash == hashed_token).first()
        if db_token:
            db_token.revoked = True
            db.commit()

auth_service = AuthService()
