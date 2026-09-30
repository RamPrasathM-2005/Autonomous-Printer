from unittest.mock import patch

import pytest
from app.config import config
from app.services.print_service import print_service
from app.utils.errors import BackendCommunicationException, OTPReleaseException


@pytest.fixture(autouse=True)
def ready_printer():
    with patch("app.routes.local.printer_monitor.get_printer_status", return_value=("READY", "AVAILABLE")):
        yield


def test_kiosk_page_and_assets(agent_client):
    response = agent_client.get("/kiosk?otp=987654")
    assert response.status_code == 200
    html = response.get_data(as_text=True)
    assert "Release code" in html and "Release print" in html
    assert "987654" not in html  # Never embed codes passed in URLs.
    assert config.AGENT_TOKEN not in html if config.AGENT_TOKEN else True
    assert "frame-ancestors 'none'" in response.headers["Content-Security-Policy"]
    assert response.headers["Cache-Control"] == "no-store"
    for asset in ("kiosk.css", "kiosk.js"):
        assert agent_client.get("/static/" + asset).status_code == 200


def test_kiosk_root_redirect(agent_client):
    response = agent_client.get("/")
    assert response.status_code == 302
    assert "/kiosk" in response.headers["Location"]


def test_kiosk_release_only_queues_and_hides_storage(agent_client):
    with patch("app.routes.local.backend_client.release_job", return_value={
        "jobId": "job_123", "orderId": "ord_456", "status": "RELEASED",
        "storageKey": "documents/private.pdf", "claimToken": "private-claim",
    }) as release, patch.object(print_service, "execute_print_job") as submit:
        response = agent_client.post("/local/release", json={"otp": "123456"},
                                     headers={"Origin": f"http://127.0.0.1:{config.PORT}"})
        assert response.status_code == 200
        assert response.json == {"status": "RELEASED", "message": "Print released.",
                                 "jobId": "job_123", "orderId": "ord_456"}
        release.assert_called_once_with("123456")
        submit.assert_not_called()


@pytest.mark.parametrize("payload", [None, [], "123456", {"otp": 123456},
    {"otp": ""}, {"otp": "123"}, {"otp": "1234567"}, {"otp": "abcdef"},
    {"otp": "\uff11\uff12\uff13\uff14\uff15\uff16"}, {"otp": "123456\n"}])
def test_invalid_payload_never_reaches_backend(agent_client, payload):
    with patch("app.routes.local.backend_client.release_job") as release:
        assert agent_client.post("/local/release", json=payload).status_code == 400
        release.assert_not_called()


@pytest.mark.parametrize("code,status", [("INVALID_OTP", 400), ("OTP_EXPIRED", 410),
    ("ORDER_ALREADY_COMPLETED", 409), ("OTP_ALREADY_USED", 409), ("RATE_LIMITED", 429)])
def test_safe_backend_errors(agent_client, code, status):
    with patch("app.routes.local.backend_client.release_job", side_effect=OTPReleaseException(
        message="internal details /private/database", error_code=code, status_code=status)):
        response = agent_client.post("/local/release", json={"otp": "123456"})
        assert response.status_code == status
        assert response.json["error"] == code
        assert "internal" not in response.json["message"]
        assert "generate" not in response.json["message"]


def test_backend_unavailable_does_not_claim_success(agent_client):
    with patch("app.routes.local.backend_client.release_job", side_effect=BackendCommunicationException("internal error")):
        response = agent_client.post("/local/release", json={"otp": "123456"})
        assert response.status_code == 503
        assert "status" not in response.json
        assert "internal" not in response.json["message"]


def test_printer_offline_does_not_consume_code(agent_client):
    with patch("app.routes.local.printer_monitor.get_printer_status", return_value=("ERROR", "UNKNOWN")), patch("app.routes.local.backend_client.release_job") as release:
        assert agent_client.post("/local/release", json={"otp": "123456"}).status_code == 503
        release.assert_not_called()


def test_local_rate_limit_precedes_backend_call(agent_client):
    with patch("app.routes.local.backend_client.release_job", side_effect=OTPReleaseException("Invalid code")) as release:
        for _ in range(10):
            assert agent_client.post("/local/release", json={"otp": "123456"}).status_code == 400
        assert agent_client.post("/local/release", json={"otp": "123456"}).status_code == 429
        assert release.call_count == 10


@pytest.mark.parametrize("headers", [{"Origin": "https://evil.example"},
    {"Origin": "null"}, {"Host": "evil.example"}, {"Origin": "http://127.0.0.1:5001"}])
def test_untrusted_origins_and_hosts(agent_client, headers):
    with patch("app.routes.local.backend_client.release_job") as release:
        assert agent_client.post("/local/release", json={"otp": "123456"}, headers=headers).status_code == 403
        release.assert_not_called()
