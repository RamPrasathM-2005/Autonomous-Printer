#!/usr/bin/env python3
"""
scripts/manage_db.py - Autonomous Cloud Print Database Management & Production Utility

Commands:
    python scripts/manage_db.py status      - Check database connection and row counts
    python scripts/manage_db.py sync        - Create missing tables and auto-migrate columns
    python scripts/manage_db.py clean-mock  - Safely purge mock orders/jobs while keeping admin & schema
"""

import sys
import time
from pathlib import Path

# Add backend directory to sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = PROJECT_ROOT / "backend"
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker
from app.config.settings import settings
from app.db.base import Base
from app.db.models.user import User, UserRole
from app.db.models.department import Department
from app.db.models.order import Order
from app.db.models.print_job import PrintJob
from app.db.models.document import Document
from app.db.models.printer import Printer
from app.db.models.print_server import PrintServer

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)

def get_status():
    print(f"\n=======================================================")
    print(f" Achuppori Autonomous Print - Database Health & Status")
    print(f"=======================================================")
    start = time.perf_counter()
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        latency_ms = round((time.perf_counter() - start) * 1000, 2)
        print(f"Connection Status : [ONLINE]")
        print(f"Database URL      : {settings.DATABASE_URL.split('@')[-1]}")
        print(f"Ping Latency      : {latency_ms} ms")
        print(f"Environment       : {settings.ENVIRONMENT}")
    except Exception as e:
        print(f"Connection Status : [FAILED]")
        print(f"Error Details     : {e}")
        sys.exit(1)

    insp = inspect(engine)
    existing_tables = set(insp.get_table_names())
    expected_tables = list(Base.metadata.tables.keys())

    print(f"\n--- Table Schema Audit ---")
    with engine.connect() as conn:
        for tbl in expected_tables:
            if tbl in existing_tables:
                try:
                    count = conn.execute(text(f"SELECT COUNT(*) FROM `{tbl}`")).scalar()
                    print(f"  [OK] {tbl:<20} : {count:>5} records")
                except Exception:
                    print(f"  [OK] {tbl:<20} : [EXISTS]")
            else:
                print(f"  [--] {tbl:<20} : [MISSING - Run 'python scripts/manage_db.py sync']")
    print(f"=======================================================\n")

def sync_schema():
    print("\n[INFO] Synchronizing production database schema...")
    Base.metadata.create_all(bind=engine)
    
    # Auto-migrate any newly declared columns
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
                    print(f"  - Added missing column: {sql}")
                    conn.execute(text(sql))
    print("[SUCCESS] Database schema is fully up to date.\n")

def clean_mock_data():
    print("\n[WARNING] Purging mock / sample development data...")
    print("This will remove test orders, documents, and print jobs, while preserving:")
    print("  - The Administrator account")
    print("  - Registered Department directories")
    print("  - Registered Printer stations")
    
    with SessionLocal() as db:
        # Delete print jobs and orders
        jobs_deleted = db.query(PrintJob).delete()
        orders_deleted = db.query(Order).delete()
        docs_deleted = db.query(Document).delete()
        
        # Delete demo users (keep admin)
        users_deleted = db.query(User).filter(User.role != UserRole.ADMIN).delete()
        db.commit()

        print(f"\n[PURGE COMPLETE]")
        print(f"  - Deleted {jobs_deleted} mock print jobs")
        print(f"  - Deleted {orders_deleted} mock orders")
        print(f"  - Deleted {docs_deleted} mock documents")
        print(f"  - Deleted {users_deleted} sample non-admin users")
        print(f"  - Primary Administrator ({settings.ADMIN_EMAIL}) preserved.\n")

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        get_status()
    elif sys.argv[1] == "sync":
        sync_schema()
        get_status()
    elif sys.argv[1] == "clean-mock":
        clean_mock_data()
        get_status()
    else:
        print(f"Unknown command: {sys.argv[1]}")
        print("Usage: python scripts/manage_db.py [status | sync | clean-mock]")
        sys.exit(1)
