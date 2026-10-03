import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    APP_NAME: str = "Achuppori"
    ENVIRONMENT: str = "development"
    HOST: str = "127.0.0.1"
    PORT: int = 8000

    DATABASE_URL: str = "mysql+pymysql://muthukumar_9360:Muthukumar12@127.0.0.1:3306/print_platform"

    JWT_SECRET_KEY: str = "CHANGE_ME_SUPER_SECRET_KEY_AT_LEAST_32_CHARS"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    STORAGE_ROOT: str = "./storage"
    MAX_UPLOAD_MB: int = 50

    OTP_TTL_MINUTES: int = 1440
    MAX_OTP_ATTEMPTS: int = 5
    MAX_PRINT_RETRIES: int = 2

    PER_PAGE_RATE: float = 2.00
    BASE_FEE: float = 0.00

    RAZORPAY_KEY_ID: str = "rzp_test_RFxhjAiTxwrpAJ"
    RAZORPAY_KEY_SECRET: str = "f7jSae5XJ4V6EfZIYTUpWB7q"
    RAZORPAY_WEBHOOK_SECRET: str = "rzp_test_webhook_secret"

    AGENT_REQUEST_TIMEOUT_SECONDS: int = 10
    HEARTBEAT_TIMEOUT_SECONDS: int = 60

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()
