from decimal import Decimal
from pydantic import Field
import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    APP_NAME: str = "PrintPlatform"
    ENVIRONMENT: str = "development"
    HOST: str = "127.0.0.1"
    PORT: int = 8000

    DATABASE_URL: str = "sqlite:///./local.db"

    JWT_SECRET_KEY: str = ""
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    STORAGE_ROOT: str = "./storage"
    MAX_UPLOAD_MB: int = 50

    OTP_TTL_MINUTES: int = 30
    MAX_OTP_ATTEMPTS: int = 5
    MAX_PRINT_RETRIES: int = 2

    PER_PAGE_RATE: Decimal = Field(default=Decimal('2.00'), gt=0)
    BASE_FEE: Decimal = Field(default=Decimal('0.00'), ge=0)

    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""

    AGENT_REQUEST_TIMEOUT_SECONDS: int = 10
    HEARTBEAT_TIMEOUT_SECONDS: int = 60

    OTP_ENCRYPTION_KEY: str = ""
    OTP_HASH_KEY: str = ""
    SESSION_TTL_HOURS: int = 24
    DOCUMENT_TTL_HOURS: int = 24
    MAX_DOCUMENT_PAGES: int = 500
    MAX_ORDER_PAGES: int = 1000
    MAX_SESSION_STORAGE_MB: int = 200
    MAX_IMAGE_PIXELS: int = 40000000
    COLOR_PAGE_RATE: Decimal = Field(default=Decimal('10.00'), gt=0)
    ALLOWED_ORIGINS: list[str] = ['http://127.0.0.1:3000', 'http://localhost:3000']
    ALLOWED_HOSTS: list[str] = ['127.0.0.1', 'localhost', 'testserver']
    ALLOW_MOCK_PRINTING: bool = False
    PAYMENT_HTTP_TIMEOUT: int = 10
    RECONCILE_INTERVAL_SECONDS: int = 30

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
