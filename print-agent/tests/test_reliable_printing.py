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


def test_file_sink_queue_cannot_print_or_advertise_ready(tmp_path, monkeypatch):
    service = CupsService()
    service.mock_mode = False
    service.has_pycups = True
    service.cups = Mock()
    connection = service.cups.Connection.return_value
    connection.getPrinters.return_value = {"HP": {"device-uri": "/dev/null", "printer-state": 3}}
    source = tmp_path / "document.pdf"
    monkeypatch.setattr(service, "prepare_printable_file", lambda *args: source)
    with pytest.raises(CupsException, match="physical device URI"):
        service.submit_job(source, {"cups_printer_name": "HP"})
    connection.printFile.assert_not_called()
    assert service.get_detected_printers()[0]["status"] == "OFFLINE"


def test_invalid_pdf_is_not_printed_as_fallback(tmp_path):
    source = tmp_path / "broken.pdf"
    source.write_bytes(b"not a PDF")
    with pytest.raises(CupsException, match="preparation failed"):
        CupsService().prepare_printable_file(source, {"orientation": "portrait"})


def test_empty_page_selection_does_not_print_entire_document(tmp_path):
    from pypdf import PdfWriter
    source = tmp_path / "single-page.pdf"
    writer = PdfWriter()
    writer.add_blank_page(width=595, height=842)
    writer.write(source)
    with pytest.raises(CupsException, match="preparation failed"):
        CupsService().prepare_printable_file(source, {"pageRange": "even"})


def test_production_does_not_treat_simulated_job_id_as_completed():
    service = CupsService()
    service.mock_mode = False
    service.has_pycups = True
    service.cups = Mock()
    assert service.monitor_job("cups-not-real", target_printer="HP") == "STATUS_UNKNOWN"


def test_recovery_exception_preserves_submission_for_next_poll(tmp_path, monkeypatch):
    journal = JobJournal(tmp_path / "recovery.sqlite3")
    entry = {"cups_job_id": "42", "printer_name": "HP"}
    journal.put("submissions", "job-42", entry)
    monkeypatch.setattr("app.services.print_service.job_journal", journal)
    monkeypatch.setattr("app.services.print_service.cups_service.monitor_job", Mock(side_effect=ConnectionError("offline")))
    service = PrintService()
    service.active_jobs.add("job-42")
    service._resume_submission("job-42", entry)
    assert journal.entries("submissions") == [("job-42", entry)]
    assert "job-42" not in service.active_jobs


def test_journal_failure_after_submission_does_not_report_print_failure(tmp_path, monkeypatch):
    service = PrintService()
    source = tmp_path / "document.pdf"
    source.write_bytes(b"document")
    monkeypatch.setattr("app.services.print_service.file_service.resolve_and_verify_file", lambda key: source)
    monkeypatch.setattr("app.services.print_service.cups_service.submit_job", lambda *args: "42")
    monkeypatch.setattr("app.services.print_service.cups_service.monitor_job", lambda *args, **kwargs: "COMPLETED")
    monkeypatch.setattr("app.services.print_service.cups_service.last_prepared_file", None)
    journal = Mock()
    journal.put.side_effect = OSError("journal unavailable")
    monkeypatch.setattr("app.services.print_service.job_journal", journal)
    report = Mock(return_value=True)
    monkeypatch.setattr("app.services.print_service.backend_client.update_job_status", report)
    assert service._do_execute("job-42", "order-42", "document.pdf", {"cups_printer_name": "HP"})
    assert [call.kwargs["status"] for call in report.call_args_list] == ["PRINTING", "COMPLETED"]
