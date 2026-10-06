import sys
from pathlib import Path

# Ensure backend root is in sys.path
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from datetime import datetime, timezone, timedelta
from app.config.database import SessionLocal, engine
from app.config.settings import settings
from app.db.base import Base
from app.db.models.department import Department
from app.db.models.user import User, UserRole
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.db.models.printer import Printer
from app.db.models.document import Document, DocumentStatus
from app.db.models.order import Order, OrderStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
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
        print("[INFO] Seeding database...")

        # 0. Departments
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

        # 1. Admin user
        admin = db.query(User).filter(User.email == settings.ADMIN_EMAIL).first()
        if not admin:
            admin = User(
                email=settings.ADMIN_EMAIL,
                full_name=settings.ADMIN_NAME,
                password_hash=hash_password(settings.ADMIN_PASSWORD),
                role=UserRole.ADMIN,
                department="Administration",
                department_id=depts["IT"].id,
                is_active=True
            )
            db.add(admin)
            print(f"  - Created admin user: {settings.ADMIN_EMAIL}")
        else:
            if not admin.department_id:
                admin.department_id = depts["IT"].id

        # 2. Demo users across departments
        demo_users = [
            {
                "email": settings.DEMO_STUDENT_EMAIL,
                "full_name": settings.DEMO_STUDENT_NAME,
                "password": settings.DEMO_STUDENT_PASSWORD,
                "dept_code": "IT",
                "roll": "2026-IT-001"
            },
            {
                "email": "sarah.hr@printplatform.local",
                "full_name": "Sarah Jenkins",
                "password": "Password123!",
                "dept_code": "HR",
                "roll": "2026-HR-002"
            },
            {
                "email": "john.fin@printplatform.local",
                "full_name": "John Davis",
                "password": "Password123!",
                "dept_code": "FIN",
                "roll": "2026-FIN-003"
            },
            {
                "email": "alex.eng@printplatform.local",
                "full_name": "Alex Mercer",
                "password": "Password123!",
                "dept_code": "ENG",
                "roll": "2026-ENG-004"
            }
        ]

        created_users = {}
        for u_data in demo_users:
            u = db.query(User).filter(User.email == u_data["email"]).first()
            if not u:
                u = User(
                    email=u_data["email"],
                    full_name=u_data["full_name"],
                    password_hash=hash_password(u_data["password"]),
                    roll_number=u_data["roll"],
                    department=depts[u_data["dept_code"]].name,
                    department_id=depts[u_data["dept_code"]].id,
                    role=UserRole.USER,
                    is_active=True
                )
                db.add(u)
                db.flush()
                print(f"  - Created user: {u_data['full_name']} ({u_data['dept_code']})")
            else:
                if not u.department_id:
                    u.department_id = depts[u_data["dept_code"]].id
                    u.department = depts[u_data["dept_code"]].name
            created_users[u_data["dept_code"]] = u

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
            server.device_token_hash = token_hash
            server.status = PrintServerStatus.ONLINE

        # 4. Printers attached to station and departments
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

        db.flush()

        # 5. Seed sample documents, orders, and print jobs if none exist
        existing_jobs = db.query(PrintJob).count()
        if existing_jobs == 0:
            print("  - Seeding sample department print jobs for dashboard...")
            now = datetime.now(timezone.utc)
            sample_jobs = [
                {
                    "dept": "FIN",
                    "user": created_users["FIN"],
                    "filename": "Q3_Financial_Audit_Report.pdf",
                    "pages": 14,
                    "copies": 2,
                    "color": False,
                    "status": PrintJobStatus.COMPLETED,
                    "order_status": OrderStatus.COMPLETED,
                    "printer": printer3,
                    "offset_hours": 2
                },
                {
                    "dept": "HR",
                    "user": created_users["HR"],
                    "filename": "Employee_Handbook_2026.pdf",
                    "pages": 28,
                    "copies": 1,
                    "color": True,
                    "status": PrintJobStatus.COMPLETED,
                    "order_status": OrderStatus.COMPLETED,
                    "printer": printer2,
                    "offset_hours": 4
                },
                {
                    "dept": "IT",
                    "user": created_users["IT"],
                    "filename": "Network_Architecture_Diagram.pdf",
                    "pages": 4,
                    "copies": 3,
                    "color": True,
                    "status": PrintJobStatus.COMPLETED,
                    "order_status": OrderStatus.COMPLETED,
                    "printer": printer1,
                    "offset_hours": 6
                },
                {
                    "dept": "ENG",
                    "user": created_users["ENG"],
                    "filename": "System_Design_Specs_v2.pdf",
                    "pages": 32,
                    "copies": 1,
                    "color": False,
                    "status": PrintJobStatus.COMPLETED,
                    "order_status": OrderStatus.COMPLETED,
                    "printer": printer1,
                    "offset_hours": 8
                },
                {
                    "dept": "HR",
                    "user": created_users["HR"],
                    "filename": "Offer_Letter_Packets.pdf",
                    "pages": 6,
                    "copies": 2,
                    "color": False,
                    "status": PrintJobStatus.COMPLETED,
                    "order_status": OrderStatus.COMPLETED,
                    "printer": printer2,
                    "offset_hours": 12
                },
                {
                    "dept": "FIN",
                    "user": created_users["FIN"],
                    "filename": "Tax_Compliance_Schedule.pdf",
                    "pages": 18,
                    "copies": 1,
                    "color": True,
                    "status": PrintJobStatus.FAILED,
                    "order_status": OrderStatus.FAILED,
                    "printer": printer3,
                    "offset_hours": 15,
                    "error": "Paper jam detected in feeder tray 2"
                },
                {
                    "dept": "IT",
                    "user": created_users["IT"],
                    "filename": "Server_Log_Analysis.pdf",
                    "pages": 10,
                    "copies": 1,
                    "color": False,
                    "status": PrintJobStatus.QUEUED,
                    "order_status": OrderStatus.JOB_QUEUED,
                    "printer": printer1,
                    "offset_hours": 1
                }
            ]

            for idx, sj in enumerate(sample_jobs):
                job_time = now - timedelta(hours=sj["offset_hours"])
                doc_id = f"doc_seed_{idx + 1:03d}"
                doc = Document(
                    id=doc_id,
                    user_id=sj["user"].id,
                    original_filename=sj["filename"],
                    stored_filename=f"{doc_id}_{sj['filename']}",
                    storage_key=f"documents/{doc_id}.pdf",
                    sha256="0" * 64,
                    file_size=sj["pages"] * 54320,
                    mime_type="application/pdf",
                    page_count=sj["pages"],
                    status=DocumentStatus.ACTIVE,
                    created_at=job_time
                )
                db.add(doc)
                db.flush()

                order_id = f"ORD-20261005-{idx + 1:04d}"
                order = Order(
                    id=order_id,
                    user_id=sj["user"].id,
                    roll_number=sj["user"].roll_number,
                    department=depts[sj["dept"]].name,
                    document_id=doc.id,
                    print_server_id=server_id,
                    print_settings={
                        "colour": sj["color"],
                        "copies": sj["copies"],
                        "sides": "double" if sj["pages"] > 10 else "single",
                        "printer_name": sj["printer"].display_name,
                        "cups_printer_name": sj["printer"].cups_printer_name
                    },
                    total_pages=sj["pages"],
                    copies=sj["copies"],
                    amount=sj["pages"] * sj["copies"] * 2.0,
                    status=sj["order_status"],
                    created_at=job_time
                )
                db.add(order)
                db.flush()

                pjob = PrintJob(
                    id=f"job_seed_{idx + 1:03d}",
                    order_id=order.id,
                    server_id=server_id,
                    printer_id=sj["printer"].id,
                    cups_job_id=f"CUPS-{100 + idx}",
                    status=sj["status"],
                    error_message=sj.get("error"),
                    created_at=job_time,
                    completed_at=(job_time + timedelta(minutes=2)) if sj["status"] == PrintJobStatus.COMPLETED else None
                )
                db.add(pjob)

        db.commit()
        print("[SUCCESS] Database seeding complete!")

    finally:
        db.close()

if __name__ == "__main__":
    seed()
