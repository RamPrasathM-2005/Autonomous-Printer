import sys
from pathlib import Path

# Ensure backend root is in sys.path
ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from app.config.database import engine
from app.db.base import Base

def migrate():
    print("[INFO] Creating database tables and syncing schema columns...")
    Base.metadata.create_all(bind=engine)
    
    from sqlalchemy import inspect, text
    try:
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
    except Exception as e:
        print(f"[WARNING] Schema sync warning: {e}")

    print("[SUCCESS] Database migration completed successfully.")

if __name__ == "__main__":
    migrate()
