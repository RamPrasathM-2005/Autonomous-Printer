from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, Boolean, Integer
from app.config.database import Base

class Printer(Base):
    __tablename__ = "printers"

    id = Column(String(64), primary_key=True, index=True)
    server_id = Column(String(64), ForeignKey("print_servers.id", ondelete="CASCADE"), nullable=False, index=True)
    department_id = Column(Integer, ForeignKey("departments.id", ondelete="SET NULL"), nullable=True, index=True)
    cups_printer_name = Column(String(255), nullable=False)
    display_name = Column(String(255), nullable=False)
    supports_color = Column(Boolean, default=True, nullable=False)
    supports_duplex = Column(Boolean, default=True, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
