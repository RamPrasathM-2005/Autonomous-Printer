"""Small durable spool journal: status delivery survives outages and Pi restarts."""
import json
import sqlite3
from contextlib import contextmanager
from app.config import config


class JobJournal:
    def __init__(self, path=None):
        self.path = path or config.STORAGE_ROOT / "agent-journal.sqlite3"
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.execute("CREATE TABLE IF NOT EXISTS pending (job_id TEXT PRIMARY KEY, payload TEXT NOT NULL)")
            db.execute("CREATE TABLE IF NOT EXISTS submissions (job_id TEXT PRIMARY KEY, payload TEXT NOT NULL)")

    @contextmanager
    def connect(self):
        connection = sqlite3.connect(str(self.path), timeout=10)
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    def put(self, table, job_id, payload):
        assert table in ("pending", "submissions")
        with self.connect() as db:
            db.execute(f"INSERT OR REPLACE INTO {table} VALUES (?, ?)", (job_id, json.dumps(payload)))

    def entries(self, table):
        assert table in ("pending", "submissions")
        with self.connect() as db:
            return [(key, json.loads(value)) for key, value in db.execute(f"SELECT * FROM {table}")]

    def remove(self, table, job_id, payload=None):
        assert table in ("pending", "submissions")
        with self.connect() as db:
            if payload is None:
                db.execute(f"DELETE FROM {table} WHERE job_id = ?", (job_id,))
            else:
                # Do not erase a newer event written while an HTTP call was in flight.
                db.execute(f"DELETE FROM {table} WHERE job_id = ? AND payload = ?", (job_id, json.dumps(payload)))


job_journal = JobJournal()
