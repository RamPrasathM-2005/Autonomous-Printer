import pytest
from app.main import create_app

@pytest.fixture
def agent_app():
    app = create_app()
    app.config["TESTING"] = True
    return app

@pytest.fixture
def agent_client(agent_app):
    return agent_app.test_client()

@pytest.fixture(autouse=True)
def isolate_station_workers(monkeypatch, tmp_path):
    # Route tests must not depend on the host's CUPS installation or private .env.
    monkeypatch.setattr("app.routes.local.printer_monitor.get_printer_status", lambda: ("READY", "AVAILABLE"))
    from app.routes.local import _recent_attempts
    _recent_attempts.clear()
    from app.services import backend_client, print_service, job_journal
    journal = job_journal.JobJournal(tmp_path / "journal.sqlite3")
    monkeypatch.setattr(backend_client, "job_journal", journal)
    monkeypatch.setattr(print_service, "job_journal", journal)
    # HTTP route tests must never send physical print jobs in background threads.
    monkeypatch.setattr("app.routes.local.job_poller.enqueue_job", lambda job: True)
    monkeypatch.setattr("app.routes.local.backend_client.poll_jobs", lambda: [])
