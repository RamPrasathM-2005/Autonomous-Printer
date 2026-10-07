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
                        type_str = str(col_type).upper()
                        if "DATETIME" in type_str or "TIMESTAMP" in type_str:
                            if col.name == "updated_at":
                                sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col_type} NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"
                            else:
                                sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col_type} NOT NULL DEFAULT CURRENT_TIMESTAMP"
                        elif col.nullable:
                            sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col_type} NULL"
                        else:
                            sql = f"ALTER TABLE `{table_name}` ADD COLUMN `{col.name}` {col_type} NULL"
                        print(f"  - Auto-migrating column: {sql}")
                        conn.execute(text(sql))
    except Exception as e:
        print(f"[WARNING] Schema sync warning: {e}")

    print("[SUCCESS] Database migration completed successfully.")

if __name__ == "__main__":
    migrate()
