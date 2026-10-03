import uuid
from datetime import datetime, timezone, timedelta
from typing import Tuple, Optional
from sqlalchemy.orm import Session
from fastapi import status

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
from app.schemas.auth import RegisterRequest, LoginRequest
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

    @staticmethod
    def login(db: Session, req: LoginRequest, admin_only: bool = False) -> Tuple[User, str, str, int]:
        user = db.query(User).filter(User.email == req.email.lower()).first()
        if not user or not verify_password(req.password, user.password_hash):
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

        token_data = {"sub": str(user.id), "role": user.role.value, "jti": uuid.uuid4().hex}
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)

        # Store refresh token hash
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
