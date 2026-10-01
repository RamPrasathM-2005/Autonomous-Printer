import json
import sqlite3
from pathlib import Path
from app.config import config

class JobJournal:
    def __init__(self):
        self.path = Path(config.STATE_ROOT) / 'jobs.sqlite3'
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS jobs (id TEXT PRIMARY KEY, payload TEXT NOT NULL, state TEXT NOT NULL, cups_id TEXT, outcome TEXT)')

    def connect(self):
        db = sqlite3.connect(self.path, timeout=15)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA synchronous=FULL')
        return db

    def prepare(self, job):
        with self.connect() as db:
            try:
                db.execute('INSERT INTO jobs(id,payload,state) VALUES (?, ?, ?)',
                           (job['jobId'], json.dumps(job), 'PREPARED'))
                return True
            except sqlite3.IntegrityError:
                return False

    def update(self, job_id, state, cups_id=None, outcome=None):
        with self.connect() as db:
            db.execute('UPDATE jobs SET state=?, cups_id=COALESCE(?,cups_id), outcome=? WHERE id=?',
                       (state, cups_id, outcome, job_id))
            if state == 'DONE':
                db.execute('UPDATE jobs SET payload=? WHERE id=?',
                           (json.dumps({'jobId': job_id}), job_id))

    def pending(self):
        with self.connect() as db:
            return [dict(r) for r in db.execute("SELECT * FROM jobs WHERE state != 'DONE'")]

journal = JobJournal()
