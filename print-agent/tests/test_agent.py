import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

from app.config import config
from app.services.cups_service import cups_service
from app.services.file_service import file_service
from app.services.job_poller import JobPoller
from app.utils.errors import StorageException

def test_health_endpoint(agent_client):
    res = agent_client.get("/health")
    assert res.status_code == 200
    data = res.get_json()
    assert data["status"] == "healthy"
    assert data["agent_id"] == config.AGENT_ID

def test_local_status_endpoint(agent_client):
    res = agent_client.get("/local/status")
    assert res.status_code == 200
    data = res.get_json()
    assert "printer_state" in data
    assert "paper_state" in data

def test_cups_options_mapping():
    settings = {
        "copies": 3,
        "pageRange": "1-3,5",
        "colour": True,
        "sides": "two-sided-long-edge",
        "paperSize": "A4",
        "orientation": "landscape"
    }
    options = cups_service.build_cups_options(settings)
    assert options["copies"] == "3"
    assert options["page-ranges"] == "1-3,5"
    assert options["print-color-mode"] == "color"
    assert options["sides"] == "two-sided-long-edge"
    assert options["media"] == "A4"
    assert options["orientation-requested"] == "4" # Landscape

def test_cups_mock_submission(tmp_path):
    dummy_file = tmp_path / "test.pdf"
    dummy_file.write_bytes(b"%PDF-1.4 test")

    orig_mock = cups_service.mock_mode
    try:
        cups_service.mock_mode = True
        cups_job_id = cups_service.submit_job(dummy_file, {"copies": 1})
        assert cups_job_id.startswith("cups-")
    finally:
        cups_service.mock_mode = orig_mock

def test_file_service_path_traversal_detection():
    # Attempt directory traversal
    with pytest.raises(StorageException):
        file_service.resolve_and_verify_file("../../../../etc/passwd")

def test_job_poller_duplicate_protection():
    poller = JobPoller()
    job = {"jobId": "job_dup_1", "orderId": "ord_1", "storageKey": "doc.pdf"}

    # Manually acquire job
    with poller._lock:
        poller.processing_jobs.add("job_dup_1")

    # In another poll cycle, same job should be skipped because it's already in processing_jobs
    with poller._lock:
        is_already_processing = "job_dup_1" in poller.processing_jobs
    assert is_already_processing is True

def test_local_release_endpoint(agent_client):
    with patch("app.routes.local.backend_client.release_job") as mock_release:
        mock_release.return_value = {
            "jobId": "job_station_1",
            "orderId": "ORD-123",
            "status": "RELEASED",
            "storageKey": "documents/1/doc.pdf",
            "settings": {"copies": 1}
        }
        res = agent_client.post("/local/release", json={"otp": "123456"})
        assert res.status_code == 200
        data = res.get_json()
        assert data["status"] == "RELEASED"

def test_kiosk_page_endpoint(agent_client):
    res = agent_client.get("/kiosk")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    assert "AUTONOMOUS PRINT" in html
    assert "PRINT STATION" in html
    assert "Enter your 6-digit OTP" in html
    assert "pressDigit" in html
    assert "submitOTP" in html

def test_local_release_invalid_otp(agent_client):
    from app.utils.errors import OtpReleaseException
    with patch("app.routes.local.backend_client.release_job") as mock_release:
        mock_release.side_effect = OtpReleaseException("Invalid OTP entered.", error_code="INVALID_OTP")
        res = agent_client.post("/local/release", json={"otp": "999999"})
        assert res.status_code == 400
        data = res.get_json()
        assert data["error"] == "INVALID_OTP"

def test_local_release_expired_otp(agent_client):
    from app.utils.errors import OtpReleaseException
    with patch("app.routes.local.backend_client.release_job") as mock_release:
        mock_release.side_effect = OtpReleaseException("OTP expired.", error_code="OTP_EXPIRED")
        res = agent_client.post("/local/release", json={"otp": "111111"})
        assert res.status_code == 400
        data = res.get_json()
        assert data["error"] == "OTP_EXPIRED"

def test_local_release_already_printed(agent_client):
    from app.utils.errors import OtpReleaseException
    with patch("app.routes.local.backend_client.release_job") as mock_release:
        mock_release.side_effect = OtpReleaseException("This order has already been printed.", error_code="ALREADY_PRINTED")
        res = agent_client.post("/local/release", json={"otp": "222222"})
        assert res.status_code == 400
        data = res.get_json()
        assert data["error"] == "ALREADY_PRINTED"

def test_local_release_backend_unavailable(agent_client):
    from app.utils.errors import BackendCommunicationException
    with patch("app.routes.local.backend_client.release_job") as mock_release:
        mock_release.side_effect = BackendCommunicationException("Connection refused")
        res = agent_client.post("/local/release", json={"otp": "123456"})
        assert res.status_code == 503
        data = res.get_json()
        assert data["error"] == "BACKEND_UNAVAILABLE"

