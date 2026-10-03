import os
import json
from typing import List, Union
from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    APP_NAME: str = "Achuppori"
    ENVIRONMENT: str = "development"
    HOST: str = "127.0.0.1"
    PORT: int = 8000

    DATABASE_URL: str = "mysql+pymysql://muthukumar_9360:Muthukumar12@127.0.0.1:3306/print_platform"

    # Auth & Tokens
    JWT_SECRET_KEY: str = ""
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    STORAGE_ROOT: str = "./storage"
    MAX_UPLOAD_MB: int = 50

    # OTP Configuration & Rate Limiting
    OTP_TTL_MINUTES: int = 1440
    MAX_OTP_ATTEMPTS: int = 5
    MAX_PRINT_RETRIES: int = 2
    OTP_COOLDOWN_SECONDS: int = 60
    OTP_RATE_LIMIT_ATTEMPTS: int = 10
    OTP_RATE_LIMIT_WINDOW_SECONDS: int = 60

    PER_PAGE_RATE: float = 2.00
    BASE_FEE: float = 0.00

    # Razorpay Secrets (Loaded strictly from environment variables)
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""

    # Internal Print Agent Secret
    INTERNAL_AGENT_TOKEN: str = "test-agent-device-token-secret"

    # CORS Allowed Origins
    ALLOWED_ORIGINS: Union[List[str], str] = [
        "http://127.0.0.1:3000",
        "http://localhost:3000",
        "http://127.0.0.1:3100",
        "http://localhost:3100",
        "http://127.0.0.1:8000",
        "http://localhost:8000",
        "http://127.0.0.1:5001",
        "http://localhost:5001",
    ]

    AGENT_REQUEST_TIMEOUT_SECONDS: int = 10
    HEARTBEAT_TIMEOUT_SECONDS: int = 60

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @model_validator(mode="after")
    def validate_and_normalize_settings(self) -> "Settings":
        # Normalize ALLOWED_ORIGINS to list if string
        if isinstance(self.ALLOWED_ORIGINS, str):
            try:
                parsed = json.loads(self.ALLOWED_ORIGINS)
                if isinstance(parsed, list):
                    self.ALLOWED_ORIGINS = parsed
                else:
                    self.ALLOWED_ORIGINS = [s.strip() for s in self.ALLOWED_ORIGINS.split(",") if s.strip()]
            except Exception:
                self.ALLOWED_ORIGINS = [s.strip() for s in self.ALLOWED_ORIGINS.split(",") if s.strip()]

        is_prod = self.ENVIRONMENT.lower() in ("production", "prod")
        insecure_keys = {
            "CHANGE_ME_SUPER_SECRET_KEY_AT_LEAST_32_CHARS",
            "secret",
            "changeme",
            "default",
            "",
        }

        if is_prod:
            missing_secrets = []
            if not self.JWT_SECRET_KEY or self.JWT_SECRET_KEY in insecure_keys:
                missing_secrets.append("JWT_SECRET_KEY (must be strong, non-default secret in production)")
            if not self.DATABASE_URL:
                missing_secrets.append("DATABASE_URL")
            if not self.INTERNAL_AGENT_TOKEN or self.INTERNAL_AGENT_TOKEN in {"test-agent-device-token-secret", ""}:
                missing_secrets.append("INTERNAL_AGENT_TOKEN (must be configured securely in production)")
            if missing_secrets:
                raise RuntimeError(
                    f"CRITICAL SECURITY CONFIGURATION ERROR: The following required production secrets are missing or insecure: {', '.join(missing_secrets)}. "
                    f"Configure them via environment variables or .env file before starting in production mode."
                )
        else:
            # Flexible development defaults
            if not self.JWT_SECRET_KEY:
                self.JWT_SECRET_KEY = "b7b577539d29ac3348a3db06598626e4c150f2e350fd9da90fc77471801dc9ca"
            if not self.RAZORPAY_KEY_ID:
                self.RAZORPAY_KEY_ID = "rzp_test_RFxhjAiTxwrpAJ"
            if not self.RAZORPAY_KEY_SECRET:
                self.RAZORPAY_KEY_SECRET = "f7jSae5XJ4V6EfZIYTUpWB7q"
            if not self.RAZORPAY_WEBHOOK_SECRET:
                self.RAZORPAY_WEBHOOK_SECRET = "rzp_test_webhook_secret"

        return self

settings = Settings()
