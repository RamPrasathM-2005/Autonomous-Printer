from pathlib import Path
from unittest.mock import Mock
import pytest
from app.services.file_service import FileService
from app.services.cups_service import CupsService
from app.services.backend_client import BackendClient
from app.services.print_service import PrintService
from app.services.job_journal import JobJournal
from app.utils.errors import StorageException, CupsException


def test_download_failure_never_creates_replacement_document(tmp_path, monkeypatch):
    service = FileService(tmp_path)
    monkeypatch.setattr("app.services.backend_client.backend_client.download_file", lambda *args: False)
    with pytest.raises(StorageException):
        service.resolve_and_verify_file("documents/missing-customer.pdf")
    assert not (tmp_path / "documents/missing-customer.pdf").exists()


@pytest.mark.parametrize("state, expected", [(9, "COMPLETED"), (7, "FAILED"), (8, "FAILED")])
def test_cups_requires_explicit_terminal_state(state, expected):
    service = CupsService()
    service.has_pycups = True
    service.mock_mode = False
    service.cups = Mock()
    service.cups.Connection.return_value.getJobAttributes.return_value = {"job-state": state}
    assert service.monitor_job("42", target_printer="Department_HP") == expected


def test_cups_query_failure_does_not_report_completed():
    service = CupsService()
    service.has_pycups = True
    service.mock_mode = False
    service.cups = Mock()
    service.cups.Connection.side_effect = ConnectionError("CUPS disconnected")
    assert service.monitor_job("42") == "STATUS_UNKNOWN"


def test_missing_selected_queue_does_not_fall_back(tmp_path):
    service = CupsService()
    service.has_pycups = True
    service.mock_mode = False
    service.printer_name = "Wrong_Default"
    service.cups = Mock()
    service.cups.Connection.return_value.getPrinters.return_value = {"Wrong_Default": {}}
    source = tmp_path / "document.pdf"
    source.write_bytes(b"%PDF-1.4")
    with pytest.raises(CupsException):
        service.submit_job(source, {"cups_printer_name": "Assigned_Queue"})
    service.cups.Connection.return_value.printFile.assert_not_called()


def test_status_outbox_survives_restart_and_replays_same_event(tmp_path, monkeypatch):
    journal = JobJournal(tmp_path / "journal.sqlite3")
    monkeypatch.setattr("app.services.backend_client.job_journal", journal)
    client = BackendClient()
    client.session = Mock()
    client.session.post.side_effect = ConnectionError("offline")
    assert client.update_job_status("job-42", "COMPLETED", cups_job_id="42") is False
    payload = journal.entries("pending")[0][1]
    restarted = JobJournal(journal.path)
    monkeypatch.setattr("app.services.backend_client.job_journal", restarted)
    client.session.post.side_effect = None
    client.session.post.return_value.status_code = 200
    client.flush_status_updates()
    assert client.session.post.call_args.kwargs["json"] == payload
    assert not restarted.entries("pending")


def test_cleanup_keeps_durable_journal(tmp_path):
    service = FileService(tmp_path)
    journal = JobJournal(tmp_path / "agent-journal.sqlite3")
    journal.put("pending", "job-42", {"status": "COMPLETED"})
    import os
    os.utime(journal.path, (0, 0))
    service.cleanup_orphaned_files(max_age_seconds=0)
    assert journal.entries("pending")[0][0] == "job-42"


def test_unclaimed_job_never_reaches_printer(monkeypatch):
    service = PrintService()
    monkeypatch.setattr("app.services.print_service.backend_client.claim_job", lambda job: False)
    execute = Mock()
    monkeypatch.setattr(service, "_do_execute", execute)
    assert service.execute_print_job({"jobId": "unclaimed-job"}) is False
    execute.assert_not_called()
