import pytest
from unittest.mock import patch
from app.config import config
from app.utils.errors import BackendCommunicationException, OTPReleaseException

def test_kiosk_html_rendering(agent_client):
    res = agent_client.get("/kiosk")
    assert res.status_code == 200
    html = res.get_data(as_text=True)
    assert "AUTONOMOUS PRINT STATION" in html
    assert "Enter your 6-digit OTP" in html
    assert "PRINT DOCUMENT" in html
    assert "HP_LaserJet_400_M401dn_E9A0F4" in html

def test_kiosk_root_redirect(agent_client):
    res = agent_client.get("/")
    assert res.status_code == 302
    assert "/kiosk" in res.headers["Location"]

def test_kiosk_release_success(agent_client):
    with patch("app.routes.local.backend_client.release_job") as mock_rel:
        mock_rel.return_value = {
            "jobId": "job_123",
            "orderId": "ORD-456",
            "status": "RELEASED",
            "storageKey": "documents/1/doc.pdf",
            "settings": {"copies": 1}
        }
        res = agent_client.post("/local/release", json={"otp": "123456"})
        assert res.status_code == 200
        data = res.get_json()
        assert data["status"] == "RELEASED"
        assert "OTP Verified. Printing Started." in data["message"]
        assert data["jobId"] == "job_123"

def test_kiosk_release_invalid_format(agent_client):
    # Non-digit or wrong length
    for bad_otp in ["", "123", "12345", "1234567", "abcdef"]:
        res = agent_client.post("/local/release", json={"otp": bad_otp})
        assert res.status_code == 400
        data = res.get_json()
        assert data["error"] == "INVALID_OTP"

def test_kiosk_release_invalid_otp_backend(agent_client):
    with patch("app.routes.local.backend_client.release_job") as mock_rel:
        mock_rel.side_effect = OTPReleaseException(
            message="Invalid OTP. Please check the OTP and try again.",
            error_code="INVALID_OTP",
            status_code=400
        )
        res = agent_client.post("/local/release", json={"otp": "999999"})
        assert res.status_code == 400
        data = res.get_json()
        assert data["error"] == "INVALID_OTP"
        assert "Invalid OTP" in data["message"]

def test_kiosk_release_expired_otp(agent_client):
    with patch("app.routes.local.backend_client.release_job") as mock_rel:
        mock_rel.side_effect = OTPReleaseException(
            message="OTP Expired. Please generate/request a new OTP.",
            error_code="OTP_EXPIRED",
            status_code=400
        )
        res = agent_client.post("/local/release", json={"otp": "111111"})
        assert res.status_code == 400
        data = res.get_json()
        assert data["error"] == "OTP_EXPIRED"
        assert "OTP Expired" in data["message"]

def test_kiosk_release_order_already_completed(agent_client):
    with patch("app.routes.local.backend_client.release_job") as mock_rel:
        mock_rel.side_effect = OTPReleaseException(
            message="This order has already been printed.",
            error_code="ORDER_ALREADY_COMPLETED",
            status_code=400
        )
        res = agent_client.post("/local/release", json={"otp": "222222"})
        assert res.status_code == 400
        data = res.get_json()
        assert data["error"] == "ORDER_ALREADY_COMPLETED"
        assert data["message"] == "This order has already been printed."

def test_kiosk_release_backend_unavailable(agent_client):
    with patch("app.routes.local.backend_client.release_job") as mock_rel:
        mock_rel.side_effect = BackendCommunicationException(
            message="FastAPI backend is unavailable. Please ensure the backend is running.",
            error_code="BACKEND_UNAVAILABLE",
            status_code=503
        )
        res = agent_client.post("/local/release", json={"otp": "333333"})
        assert res.status_code == 503
        data = res.get_json()
        assert data["error"] == "BACKEND_UNAVAILABLE"

def test_kiosk_release_printer_offline(agent_client):
    with patch("app.routes.local.printer_monitor.get_printer_status") as mock_mon:
        mock_mon.return_value = ("ERROR", "UNAVAILABLE")
        res = agent_client.post("/local/release", json={"otp": "444444"})
        assert res.status_code == 503
        data = res.get_json()
        assert data["error"] == "PRINTER_OFFLINE"
        assert "Printer is currently offline" in data["message"]
