from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models.user import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, RefreshTokenRequest, UserResponse
from app.schemas.common import MessageResponse
from app.services.auth_service import auth_service
from app.api.dependencies import get_current_user

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

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
        expires_in=expires_in
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
