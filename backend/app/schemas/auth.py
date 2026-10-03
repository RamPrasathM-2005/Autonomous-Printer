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
    # The local seed account uses a reserved, non-deliverable domain.
    if value == "admin@printplatform.local":
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
    email: str = Field(..., max_length=254)
    password: str
    phone: Optional[str] = None
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
