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
from app.db.models.department import Department
from app.db.models.user import User, UserRole
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer
from app.config.security import hash_password, hash_token

def sync_missing_columns():
    from sqlalchemy import inspect, text
    insp = inspect(engine)
    with engine.begin() as conn:
        for table_name, table in Base.metadata.tables.items():
            if not insp.has_table(table_name):
                continue
            db_cols = {c['name'] for c in insp.get_columns(table_name)}
            for col in table.columns:
                if col.name not in db_cols:
                    col_type = col.type.compile(engine.dialect)
                    nullable = "NULL" if col.nullable else "NOT NULL"
                    sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col_type} {nullable}"
                    print(f"  - Auto-migrating column: {sql}")
                    conn.execute(text(sql))

def seed():
    # Ensure tables exist and missing columns are added
    Base.metadata.create_all(bind=engine)
    sync_missing_columns()
    db = SessionLocal()

    try:
        print("[INFO] Seeding database infrastructure...")

        # 0. Departments master data
        departments_data = [
            {"code": "HR", "name": "Human Resources", "description": "People and Culture Department"},
            {"code": "FIN", "name": "Finance", "description": "Finance and Accounts Department"},
            {"code": "IT", "name": "Information Technology", "description": "IT Infrastructure and Support"},
            {"code": "ENG", "name": "Engineering", "description": "Engineering and R&D Department"},
            {"code": "MKT", "name": "Marketing", "description": "Marketing and Communications"},
        ]
        depts = {}
        for d_data in departments_data:
            dept = db.query(Department).filter(Department.code == d_data["code"]).first()
            if not dept:
                dept = Department(
                    code=d_data["code"],
                    name=d_data["name"],
                    description=d_data["description"]
                )
                db.add(dept)
                db.flush()
                print(f"  - Created department: {d_data['name']} ({d_data['code']})")
            depts[d_data["code"]] = dept

        # 1. Administrator account from environment
        if settings.ADMIN_EMAIL and settings.ADMIN_PASSWORD:
            admin_email = settings.ADMIN_EMAIL.strip().lower()
            admin = db.query(User).filter(User.email == admin_email).first()
            if not admin:
                admin = User(
                    email=admin_email,
                    full_name=settings.ADMIN_NAME or "Platform Administrator",
                    password_hash=hash_password(settings.ADMIN_PASSWORD),
                    role=UserRole.ADMIN,
                    department="Administration",
                    department_id=depts["IT"].id,
                    is_active=True
                )
                db.add(admin)
                print(f"  - Created admin user: {admin_email}")
            else:
                if not admin.department_id:
                    admin.department_id = depts["IT"].id

        # 2. Print Server Station
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
            server.device_token_hash = token_hash
            server.status = PrintServerStatus.ONLINE

        # 3. Printers attached to station and departments
        printer1 = db.query(Printer).filter(Printer.id == "printer_central_01").first()
        if not printer1:
            printer1 = Printer(
                id="printer_central_01",
                server_id=server_id,
                department_id=depts["IT"].id,
                cups_printer_name="HP_LaserJet_400_M401dn_F36EC0",
                display_name="HP LaserJet 400 M401dn (IT Lab)",
                supports_color=False,
                supports_duplex=True,
                is_active=True
            )
            db.add(printer1)
            print("  - Created printer 1: HP LaserJet 400 M401dn (IT)")
        else:
            printer1.department_id = depts["IT"].id

        printer2 = db.query(Printer).filter(Printer.id == "printer_central_02").first()
        if not printer2:
            printer2 = Printer(
                id="printer_central_02",
                server_id=server_id,
                department_id=depts["HR"].id,
                cups_printer_name="HP_LaserJet_400_M401dn_E9A0F4",
                display_name="HP LaserJet 400 M401dn (HR Floor)",
                supports_color=True,
                supports_duplex=True,
                is_active=True
            )
            db.add(printer2)
            print("  - Created printer 2: HP LaserJet 400 M401dn (HR)")
        else:
            printer2.department_id = depts["HR"].id

        printer3 = db.query(Printer).filter(Printer.id == "printer_central_03").first()
        if not printer3:
            printer3 = Printer(
                id="printer_central_03",
                server_id=server_id,
                department_id=depts["FIN"].id,
                cups_printer_name="Canon_imageRUNNER_2520",
                display_name="Canon imageRUNNER 2520 (Finance)",
                supports_color=True,
                supports_duplex=True,
                is_active=True
            )
            db.add(printer3)
            print("  - Created printer 3: Canon imageRUNNER 2520 (Finance)")

        db.commit()
        print("[SUCCESS] Infrastructure database seeding complete! Student accounts & logs are created dynamically on user login.")

    finally:
        db.close()

if __name__ == "__main__":
    seed()
