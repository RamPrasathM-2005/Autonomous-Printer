import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file
AGENT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(AGENT_ROOT / ".env")

def normalize_backend_url(raw_url: str) -> str:
    cleaned = (raw_url or "").strip().rstrip("/")
    if not cleaned:
        return "http://127.0.0.1:8000/api"
    if not cleaned.endswith("/api"):
        cleaned = f"{cleaned}/api"
    return cleaned

class Config:
    AGENT_ID: str = os.getenv("AGENT_ID", "PRINT-SERVER-001")
    BACKEND_URL: str = normalize_backend_url(os.getenv("BACKEND_URL", "http://127.0.0.1:8000/api"))
    AGENT_TOKEN: str = os.getenv("AGENT_TOKEN", "test-agent-device-token-secret")
    STORAGE_ROOT: Path = (AGENT_ROOT / os.getenv("STORAGE_ROOT", "./storage")).resolve()
    LOG_DIR: Path = (AGENT_ROOT / os.getenv("LOG_DIR", "./logs")).resolve()

    # Optimized intervals for Raspberry Pi 3B continuous 24/7 operation
    POLL_INTERVAL_SECONDS: int = int(os.getenv("POLL_INTERVAL_SECONDS", "10"))
    HEARTBEAT_INTERVAL_SECONDS: int = int(os.getenv("HEARTBEAT_INTERVAL_SECONDS", "30"))
    BACKOFF_MAX_SECONDS: int = int(os.getenv("BACKOFF_MAX_SECONDS", "30"))

    # Memory and storage boundaries
    MIN_FREE_DISK_MB: int = int(os.getenv("MIN_FREE_DISK_MB", "200"))
    MAX_CACHE_JOBS: int = int(os.getenv("MAX_CACHE_JOBS", "100"))
    MAX_CONCURRENT_JOBS: int = max(1, int(os.getenv("MAX_CONCURRENT_JOBS", "1")))

    CUPS_SERVER: str = os.getenv("CUPS_SERVER", "localhost")
    PRINTER_NAME: str = os.getenv("PRINTER_NAME", "")
    PORT: int = int(os.getenv("PORT", "5001"))
    MOCK_CUPS: bool = os.getenv("MOCK_CUPS", "false").lower() in ("true", "1", "yes")
    INTERNAL_AGENT_TOKEN: str = os.getenv("INTERNAL_AGENT_TOKEN", os.getenv("AGENT_TOKEN", "test-agent-device-token-secret"))

config = Config()

