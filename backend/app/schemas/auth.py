from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr, ConfigDict, Field, field_validator, TypeAdapter
from app.db.models.user import UserRole

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    phone: Optional[str] = None
    full_name: Optional[str] = None

class LoginRequest(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(min_length=1, max_length=1024)

    @field_validator("email")
    @classmethod
    def validate_login_email(cls, value: str) -> str:
        value = value.strip().lower()
        # The local seed account uses a reserved, non-deliverable domain.
        if value == "admin@printplatform.local":
            return value
        return str(TypeAdapter(EmailStr).validate_python(value))

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    phone: Optional[str] = None
    full_name: Optional[str] = None
    role: UserRole
    is_active: bool
    created_at: datetime
