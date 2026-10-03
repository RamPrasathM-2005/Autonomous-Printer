"""Initialize only a fresh development SQLite station, without demo accounts."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from dotenv import dotenv_values
from app.config.settings import settings
from app.config.database import engine, SessionLocal
from app.config.security import hash_token
from app.db.base import Base
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer


def main():
    agent = dotenv_values(ROOT / "print-agent/.env")
    if settings.ENVIRONMENT != "development" or not settings.DATABASE_URL.startswith("sqlite:"):
        raise RuntimeError("Local initialization requires development SQLite configuration.")
    if agent.get("MOCK_CUPS", "").lower() != "true":
        raise RuntimeError("Local initialization requires simulated printing.")
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        station_id = agent["AGENT_ID"]
        if db.get(PrintServer, station_id):
            return
        db.add(PrintServer(
            id=station_id, name="Local print station", location="Development",
            device_token_hash=hash_token(agent["AGENT_TOKEN"]),
            status=PrintServerStatus.OFFLINE,
        ))
        db.flush()
        db.add(Printer(
            id="local-printer", server_id=station_id,
            cups_printer_name=agent["PRINTER_NAME"], display_name="Local printer",
            supports_color=True, supports_duplex=True, is_active=True,
        ))
        db.commit()
    print("Created local simulated station.")


if __name__ == "__main__":
    main()
