from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.user import User
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    TokenResponse,
    RefreshTokenRequest,
    UserResponse,
    SendPhoneOtpRequest,
    VerifyPhoneOtpRequest,
    StudentRegisterRequest,
    StudentLoginRequest,
    UpdateProfileRequest,
)
from app.schemas.common import MessageResponse
from app.services.auth_service import auth_service
from app.config.settings import settings
from app.api.dependencies import get_current_user, get_current_admin

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.post("/send-otp")
def send_phone_otp(req: SendPhoneOtpRequest, db: Session = Depends(get_db)):
    otp = auth_service.send_phone_otp(db, req.phone, req.purpose or "login")
    resp = {"message": "Verification code sent successfully.", "phone": req.phone}
    if settings.ENVIRONMENT == "development":
        resp["dev_otp"] = otp
    return resp

@router.post("/verify-otp")
def verify_phone_otp(req: VerifyPhoneOtpRequest):
    auth_service.verify_phone_otp(req.phone, req.otp)
    return {"message": "Verification code is valid.", "valid": True}

@router.post("/student/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def student_signup(req: StudentRegisterRequest, db: Session = Depends(get_db)):
    user, access_token, refresh_token, expires_in = auth_service.student_register(db, req)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=expires_in,
        user=UserResponse.model_validate(user),
    )

@router.post("/student/login", response_model=TokenResponse)
def student_login(req: StudentLoginRequest, db: Session = Depends(get_db)):
    user, access_token, refresh_token, expires_in = auth_service.student_login(db, req)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=expires_in,
        user=UserResponse.model_validate(user),
    )

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def register_user(req: RegisterRequest, db: Session = Depends(get_db)):
    user = auth_service.register(db, req)
    return user

@router.post("/login", response_model=TokenResponse)
def login_user(req: LoginRequest, db: Session = Depends(get_db)):
    user, access_token, refresh_token, expires_in = auth_service.login(db, req)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=expires_in,
        user=UserResponse.model_validate(user),
    )

@router.post("/refresh", response_model=TokenResponse)
def refresh_token(req: RefreshTokenRequest, db: Session = Depends(get_db)):
    new_access_token, expires_in = auth_service.refresh_access_token(db, req.refresh_token)
    return TokenResponse(
        access_token=new_access_token,
        refresh_token=req.refresh_token,
        token_type="Bearer",
        expires_in=expires_in
    )

@router.post("/logout", response_model=MessageResponse)
def logout_user(req: RefreshTokenRequest, db: Session = Depends(get_db)):
    auth_service.logout(db, req.refresh_token)
    return MessageResponse(message="Logged out successfully.")

@router.get("/me", response_model=UserResponse)
def get_current_user_profile(user: User = Depends(get_current_user)):
    return user

@router.put("/me", response_model=UserResponse)
def update_current_user_profile(
    req: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    updated = auth_service.update_profile(db, user, req)
    return updated

@router.post("/admin/login", response_model=TokenResponse)
def login_admin(req: LoginRequest, db: Session = Depends(get_db)):
    user, access_token, refresh_token, expires_in = auth_service.login(db, req, admin_only=True)
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=expires_in,
        user=UserResponse.model_validate(user)
    )

@router.get("/admin/me", response_model=UserResponse)
def get_admin_profile(user: User = Depends(get_current_admin)):
    return user
