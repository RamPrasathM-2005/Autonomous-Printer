import sys
from pathlib import Path

# Ensure backend root is in sys.path
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from sqlalchemy import text
from app.config.database import engine
from app.db.base import Base
from app.db.seed import seed

def reset_database():
    print("[RESET] Starting database reset for 'printer' database...")
    with engine.connect() as conn:
        print("[RESET] Disabling foreign key checks...")
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))
        conn.commit()

        # Get all table names in the current database
        result = conn.execute(text(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE();"
        ))
        tables = [row[0] for row in result.fetchall()]
        print(f"[RESET] Found {len(tables)} tables to drop: {tables}")

        for table in tables:
            print(f"  - Dropping table: {table}")
            conn.execute(text(f"DROP TABLE IF EXISTS `{table}`;"))
        conn.commit()

        print("[RESET] Re-enabling foreign key checks...")
        conn.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
        conn.commit()

    print("[RESET] Creating all database tables with updated schema...")
    Base.metadata.create_all(bind=engine)
    print("[RESET] All tables created successfully!")

    print("[RESET] Running database seeder...")
    seed()
    print("[RESET] Complete! Database has been cleanly reset and initialized.")

if __name__ == "__main__":
    reset_database()
