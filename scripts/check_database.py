"""Read-only schema, uniqueness and orphan checks; never prints credentials or row contents."""
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT / "backend")
sys.path.insert(0, str(ROOT / "backend"))
from sqlalchemy import inspect, select, func, and_
from app.config.database import engine
from app.db.base import Base


def main():
    inspector = inspect(engine)
    existing = set(inspector.get_table_names())
    issues = []
    with engine.connect() as connection:
        for name, table in Base.metadata.tables.items():
            if name not in existing:
                issues.append(f"{name}: missing table")
                continue
            columns = {column['name'] for column in inspector.get_columns(name)}
            missing = set(table.columns.keys()) - columns
            if missing:
                issues.append(f"{name}: missing columns {', '.join(sorted(missing))}")
                continue
            count = connection.scalar(select(func.count()).select_from(table))
            print(f"{name}: {count} rows")
            for constraint in table.constraints:
                if constraint.__class__.__name__ != 'UniqueConstraint':
                    continue
                keys = list(constraint.columns)
                duplicates = select(*keys).where(and_(*(c.is_not(None) for c in keys))).group_by(*keys).having(func.count() > 1).subquery()
                if connection.scalar(select(func.count()).select_from(duplicates)):
                    issues.append(f"{name}: duplicate unique values")
            for foreign in table.foreign_keys:
                source, target = foreign.parent, foreign.column
                if target.table.name not in existing:
                    issues.append(f"{name}: missing referenced table {target.table.name}")
                    continue
                joined = table.outerjoin(target.table, source == target)
                orphan_count = connection.scalar(select(func.count()).select_from(joined).where(source.is_not(None), target.is_(None)))
                if orphan_count:
                    issues.append(f"{name}.{source.name}: {orphan_count} orphan references")
        # Foreign keys alone cannot detect an order stranded between workflow states.
        if not issues:
            from app.db.models.order import Order
            from app.db.models.print_job import PrintJob
            from app.db.models.payment import Payment
            orders, jobs, payments = Order.__table__, PrintJob.__table__, Payment.__table__
            valid_jobs = {
                "WAITING_FOR_OTP": {"QUEUED"}, "JOB_QUEUED": {"QUEUED"},
                "RELEASED": {"RELEASED"}, "PRINTING": {"PRINTING", "RELEASED"},
                "COMPLETED": {"COMPLETED"},
            }
            rows = connection.execute(select(orders.c.id, orders.c.status, jobs.c.status.label("job_status"))
                                      .select_from(orders.outerjoin(jobs, orders.c.id == jobs.c.order_id)))
            for row in rows:
                order_state = row.status.value
                job_state = row.job_status.value if row.job_status else None
                if order_state in valid_jobs and job_state not in valid_jobs[order_state]:
                    issues.append(f"order {row.id}: {order_state} but job is {job_state or 'missing'}; inspect before retrying")
            unpaid = connection.execute(select(orders.c.id).select_from(
                orders.outerjoin(payments, orders.c.id == payments.c.order_id)).where(
                    orders.c.status.in_(["WAITING_FOR_OTP", "RELEASED", "PRINTING", "COMPLETED"]),
                    (payments.c.id.is_(None)) | (payments.c.status != "CAPTURED")))
            for row in unpaid:
                issues.append(f"order {row.id}: payable/printed state without captured payment")
    for issue in issues:
        print("CONFLICT: " + issue)
    print(f"Database audit: {len(issues)} conflicts.")
    return 1 if issues else 0


if __name__ == '__main__':
    raise SystemExit(main())
