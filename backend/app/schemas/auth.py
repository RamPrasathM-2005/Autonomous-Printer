from datetime import datetime
import re
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator
from app.db.models.user import UserRole

# Type alias for backward compatibility
EmailStr = str

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$")

def validate_email_address(value: str) -> str:
    if not isinstance(value, str):
        raise ValueError("Email must be a string")
    value = value.strip().lower()
    if not value or len(value) > 254:
        raise ValueError("Email length must be between 1 and 254 characters")
    # Allow configured admin email or local internal test domains
    from app.config.settings import settings
    if (hasattr(settings, "ADMIN_EMAIL") and settings.ADMIN_EMAIL and value == settings.ADMIN_EMAIL.strip().lower()) or value.endswith(".local"):
        return value
    try:
        from email_validator import validate_email, EmailNotValidError
        validated = validate_email(value, check_deliverability=False)
        return validated.normalized
    except ImportError:
        pass
    except Exception as e:
        raise ValueError(str(e))
    if not EMAIL_REGEX.match(value):
        raise ValueError("value is not a valid email address")
    return value

class RegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(..., max_length=254)
    password: str
    full_name: Optional[str] = None

    @field_validator("email")
    @classmethod
    def validate_register_email(cls, value: str) -> str:
        return validate_email_address(value)

class LoginRequest(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(min_length=1, max_length=1024)

    @field_validator("email")
    @classmethod
    def validate_login_email(cls, value: str) -> str:
        return validate_email_address(value)

class SendOtpRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(..., max_length=254, description="User email address")
    purpose: Optional[str] = Field("login", description="Purpose: 'login' or 'signup'")

    @field_validator("email")
    @classmethod
    def validate_send_otp_email(cls, value: str) -> str:
        return validate_email_address(value)

class VerifyOtpRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(..., max_length=254, description="User email address")
    otp: str = Field(..., min_length=4, max_length=8)

    @field_validator("email")
    @classmethod
    def validate_verify_otp_email(cls, value: str) -> str:
        return validate_email_address(value)

class StudentRegisterRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    full_name: str = Field(..., min_length=2, max_length=100)
    roll_number: str = Field(..., min_length=2, max_length=50)
    email: str = Field(..., min_length=5, max_length=254)
    department: str = Field(..., min_length=2, max_length=100)
    otp: str = Field(..., min_length=4, max_length=8)

    @field_validator("email")
    @classmethod
    def validate_student_reg_email(cls, value: str) -> str:
        return validate_email_address(value)

class StudentLoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(..., max_length=254, description="Student email address")
    otp: str = Field(..., min_length=4, max_length=8)

    @field_validator("email")
    @classmethod
    def validate_student_login_email(cls, value: str) -> str:
        return validate_email_address(value)

class UpdateProfileRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    full_name: Optional[str] = None
    department: Optional[str] = None
    email: Optional[str] = None

    @field_validator("email")
    @classmethod
    def validate_update_email(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and value.strip():
            return validate_email_address(value)
        return value

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int
    user: Optional["UserResponse"] = None

class RefreshTokenRequest(BaseModel):
    refresh_token: str

class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: Optional[str] = None
    full_name: Optional[str] = None
    roll_number: Optional[str] = None
    department: Optional[str] = None
    role: UserRole
    is_active: bool
    created_at: datetime
