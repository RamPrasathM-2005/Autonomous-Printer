import sys
from pathlib import Path

# Ensure backend root is in sys.path
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from datetime import datetime, timezone
from app.config.database import SessionLocal, engine
from app.config.settings import settings
from app.db.base import Base
from app.db.models.user import User, UserRole
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer
from app.config.security import hash_password, hash_token

def seed():
    # Ensure tables exist
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    try:
        print("[INFO] Seeding database...")

        # 1. Admin user
        admin = db.query(User).filter(User.email == settings.ADMIN_EMAIL).first()
        if not admin:
            admin = User(
                email=settings.ADMIN_EMAIL,
                phone=settings.ADMIN_PHONE,
                full_name=settings.ADMIN_NAME,
                password_hash=hash_password(settings.ADMIN_PASSWORD),
                role=UserRole.ADMIN,
                is_active=True
            )
            db.add(admin)
            print(f"  - Created admin user: {settings.ADMIN_EMAIL}")

        # 2. Demo student user
        student = db.query(User).filter(User.email == settings.DEMO_STUDENT_EMAIL).first()
        if not student:
            student = User(
                email=settings.DEMO_STUDENT_EMAIL,
                phone=settings.DEMO_STUDENT_PHONE,
                full_name=settings.DEMO_STUDENT_NAME,
                password_hash=hash_password(settings.DEMO_STUDENT_PASSWORD),
                role=UserRole.USER,
                is_active=True
            )
            db.add(student)
            print(f"  - Created demo student user: {settings.DEMO_STUDENT_EMAIL}")

        # 3. Print Server Station
        server_id = settings.DEFAULT_PRINT_SERVER_ID
        server = db.query(PrintServer).filter(PrintServer.id == server_id).first()
        agent_token = settings.INTERNAL_AGENT_TOKEN
        token_hash = hash_token(agent_token)

        if not server:
            server = PrintServer(
                id=server_id,
                name=settings.DEFAULT_PRINT_SERVER_NAME,
                location=settings.DEFAULT_PRINT_SERVER_LOCATION,
                device_token_hash=token_hash,
                status=PrintServerStatus.ONLINE,
                last_heartbeat=datetime.now(timezone.utc),
                printer_state="READY",
                paper_state="AVAILABLE"
            )
            db.add(server)
            print(f"  - Created print station: {server_id}")
        else:
            # Update token hash if needed
            server.device_token_hash = token_hash
            server.status = PrintServerStatus.ONLINE

        # 4. Printers attached to station
        printer = db.query(Printer).filter(Printer.id == "printer_central_01").first()
        if not printer:
            printer = Printer(
                id="printer_central_01",
                server_id=server_id,
                cups_printer_name="HP_LaserJet_400_M401dn_F36EC0",
                display_name="HP LaserJet 400 M401dn",
                supports_color=False,
                supports_duplex=True,
                is_active=True
            )
            db.add(printer)
            print("  - Created printer 1: HP_LaserJet_400_M401dn_F36EC0 (Duplex B&W)")
        else:
            printer.server_id = server_id
            printer.cups_printer_name = "HP_LaserJet_400_M401dn_F36EC0"
            printer.display_name = "HP LaserJet 400 M401dn"
            printer.supports_color = False
            printer.supports_duplex = True

        printer2 = db.query(Printer).filter(Printer.id == "printer_central_02").first()
        if not printer2:
            printer2 = Printer(
                id="printer_central_02",
                server_id=server_id,
                cups_printer_name="HP_LaserJet_400_M401dn_E9A0F4",
                display_name="HP LaserJet 400 M401dn (Unit 2)",
                supports_color=False,
                supports_duplex=True,
                is_active=True
            )
            db.add(printer2)
            print("  - Created printer 2: HP_LaserJet_400_M401dn_E9A0F4 (Unit 2)")
        else:
            printer2.server_id = server_id
            printer2.cups_printer_name = "HP_LaserJet_400_M401dn_E9A0F4"
            printer2.display_name = "HP LaserJet 400 M401dn (Unit 2)"
            printer2.supports_color = False
            printer2.supports_duplex = True

        db.commit()
        print("[SUCCESS] Database seeding complete!")

    finally:
        db.close()

if __name__ == "__main__":
    seed()
