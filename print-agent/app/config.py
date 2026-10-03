import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file
load_dotenv()

class Config:
    AGENT_ID: str = os.getenv("AGENT_ID", "PRINT-SERVER-001")
    BACKEND_URL: str = os.getenv("BACKEND_URL", "http://127.0.0.1:8000/api").rstrip("/")
    AGENT_TOKEN: str = os.getenv("AGENT_TOKEN", "test-agent-device-token-secret")
    STORAGE_ROOT: Path = Path(os.getenv("STORAGE_ROOT", "./storage")).resolve()

    POLL_INTERVAL_SECONDS: int = int(os.getenv("POLL_INTERVAL_SECONDS", "3"))
    HEARTBEAT_INTERVAL_SECONDS: int = int(os.getenv("HEARTBEAT_INTERVAL_SECONDS", "15"))

    CUPS_SERVER: str = os.getenv("CUPS_SERVER", "localhost")
    PRINTER_NAME: str = os.getenv("PRINTER_NAME", "HP_LaserJet_400_M401dn_E9A0F4")
    PORT: int = int(os.getenv("PORT", "5001"))
    MOCK_CUPS: bool = os.getenv("MOCK_CUPS", "false").lower() in ("true", "1", "yes")
    INTERNAL_AGENT_TOKEN: str = os.getenv("INTERNAL_AGENT_TOKEN", os.getenv("AGENT_TOKEN", "test-agent-device-token-secret"))

config = Config()
