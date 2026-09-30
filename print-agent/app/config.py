import os
from pathlib import Path
from dotenv import load_dotenv

# Load .env file
load_dotenv(Path(__file__).resolve().parents[1] / '.env')

class Config:
    AGENT_ID: str = os.getenv("AGENT_ID", "PRINT-SERVER-001")
    BACKEND_URL: str = os.getenv("BACKEND_URL", "http://127.0.0.1:8000/api").rstrip("/")
    AGENT_TOKEN: str = os.getenv("AGENT_TOKEN", "")
    STORAGE_ROOT: Path = Path(os.getenv("STORAGE_ROOT", "./storage")).resolve()

    STATE_ROOT: Path = Path(os.getenv('STATE_ROOT', './state')).resolve()
    ALLOWED_ORIGINS: list[str] = os.getenv('ALLOWED_ORIGINS', 'http://127.0.0.1:3000,http://localhost:3000').split(',')

    POLL_INTERVAL_SECONDS: int = int(os.getenv("POLL_INTERVAL_SECONDS", "3"))
    HEARTBEAT_INTERVAL_SECONDS: int = int(os.getenv("HEARTBEAT_INTERVAL_SECONDS", "15"))

    CUPS_SERVER: str = os.getenv("CUPS_SERVER", "localhost")
    PRINTER_NAME: str = os.getenv("PRINTER_NAME", "Default_Office_Printer")
    MOCK_CUPS: bool = os.getenv("MOCK_CUPS", "false").lower() in ("true", "1", "yes")

config = Config()
