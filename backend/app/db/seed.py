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
                    col_type_str = str(col.type.compile(engine.dialect)).upper()
                    if "DATETIME" in col_type_str or "TIMESTAMP" in col_type_str:
                        sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col.type.compile(engine.dialect)} NULL DEFAULT CURRENT_TIMESTAMP"
                    elif "BOOLEAN" in col_type_str or "BOOL" in col_type_str:
                        default_val = "1" if getattr(col, "default", None) and getattr(col.default, "arg", None) is True else "0"
                        sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col.type.compile(engine.dialect)} NOT NULL DEFAULT {default_val}"
                    else:
                        sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col.type.compile(engine.dialect)} NULL"
                    print(f"  - Auto-migrating column: {sql}")
                    conn.execute(text(sql))

def seed():
    # Ensure tables exist and missing columns are added
    Base.metadata.create_all(bind=engine)
    sync_missing_columns()
    db = SessionLocal()

    try:
        print("[INFO] Seeding database infrastructure...")

        # 0. Real Campus Departments master data
        departments_data = [
            {"code": "CSE", "name": "Computer Science and Engineering", "description": "Department of Computer Science and Engineering"},
            {"code": "ECE", "name": "Electronics and Communication Engineering", "description": "Department of Electronics and Communication Engineering"},
            {"code": "EEE", "name": "Electrical and Electronics Engineering", "description": "Department of Electrical and Electronics Engineering"},
            {"code": "MECH", "name": "Mechanical Engineering", "description": "Department of Mechanical Engineering"},
            {"code": "CIVIL", "name": "Civil Engineering", "description": "Department of Civil Engineering"},
            {"code": "IT", "name": "Information Technology", "description": "Department of Information Technology"},
            {"code": "AIDS", "name": "Artificial Intelligence and Data Science", "description": "Department of Artificial Intelligence and Data Science"},
            {"code": "MBA", "name": "Management Studies", "description": "Department of Management Studies"},
            {"code": "S&H", "name": "Science and Humanities", "description": "Department of Science and Humanities"},
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
            else:
                dept.name = d_data["name"]
                dept.description = d_data["description"]
                db.flush()
            depts[d_data["code"]] = dept

        # Remove legacy sample corporate departments if unlinked
        dummy_codes = ["HR", "FIN", "ENG", "MKT"]
        for dcode in dummy_codes:
            old_dept = db.query(Department).filter(Department.code == dcode).first()
            if old_dept:
                users_with_dept = db.query(User).filter(User.department_id == old_dept.id).count()
                printers_with_dept = db.query(Printer).filter(Printer.department_id == old_dept.id).count()
                if users_with_dept == 0 and printers_with_dept == 0:
                    db.delete(old_dept)
                    print(f"  - Cleaned up legacy placeholder department: {dcode}")

        # Link any unlinked users to matching department
        import re
        for u in db.query(User).all():
            if not u.department_id and u.department:
                dept_match = db.query(Department).filter(
                    (Department.name.ilike(u.department)) |
                    (Department.code.ilike(u.department)) |
                    (Department.name.ilike(f"%{u.department}%"))
                ).first()
                if not dept_match:
                    code_match = re.search(r'\(([^)]+)\)', u.department)
                    if code_match:
                        code_extracted = code_match.group(1).strip()
                        dept_match = db.query(Department).filter(
                            (Department.code.ilike(code_extracted)) |
                            (Department.name.ilike(f"%{code_extracted}%"))
                        ).first()
                if dept_match:
                    u.department_id = dept_match.id
                    u.department = dept_match.name
                    print(f"  - Linked user {u.email} to department {dept_match.name} ({dept_match.code})")
        db.flush()

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

        # 2. Print Server Station (Pi Station mapped to department)
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
                department_id=depts["CSE"].id,
                status=PrintServerStatus.ONLINE,
                last_heartbeat=datetime.now(timezone.utc),
                printer_state="READY",
                paper_state="AVAILABLE"
            )
            db.add(server)
            print(f"  - Created print station: {server_id} mapped to CSE Department")
        else:
            server.device_token_hash = token_hash
            server.status = PrintServerStatus.ONLINE
            if not server.department_id:
                server.department_id = depts["CSE"].id

        db.commit()
        print("[SUCCESS] Infrastructure database seeding complete! Master departments and admin created. Printers and agents are dynamically registered.")

    finally:
        db.close()

if __name__ == "__main__":
    seed()
