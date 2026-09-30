import requests
from typing import List, Dict, Any, Optional
from app.config import config
from app.utils.errors import BackendCommunicationException, OTPReleaseException
from app.utils.logging import agent_logger

class BackendClient:
    def __init__(self):
        self.base_url = config.BACKEND_URL
        self.token = config.AGENT_TOKEN
        self.session = requests.Session()
        self.session.headers.update({
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "User-Agent": f"PrintAgent/{config.AGENT_ID}"
        })

    def send_heartbeat(self, printer_state: str = "READY", paper_state: str = "AVAILABLE") -> bool:
        url = f"{self.base_url}/agent/heartbeat"
        try:
            resp = self.session.post(url, json={
                "printerState": printer_state,
                "paperState": paper_state, "mockPrinting": config.MOCK_CUPS
            }, timeout=5)
            if resp.status_code == 200:
                return True
            agent_logger.warning(f"Heartbeat responded with status code: {resp.status_code}")
            return False
        except Exception as e:
            agent_logger.warning(f"Heartbeat error: {e}")
            return False

    def poll_jobs(self) -> List[Dict[str, Any]]:
        url = f"{self.base_url}/agent/jobs"
        try:
            resp = self.session.get(url, timeout=10)
            if resp.status_code == 200:
                return resp.json()
            agent_logger.error(f"Job poll failed with status {resp.status_code}: {resp.text}")
            return []
        except Exception as e:
            agent_logger.error(f"Failed to connect to backend for job polling: {e}")
            return []

    def claim_job(self, job_id):
        try:
            resp = self.session.post(f'{self.base_url}/agent/jobs/{job_id}/claim', timeout=15)
            if resp.status_code == 200:
                return resp.json()
            return None
        except requests.RequestException:
            # Do not submit if the claim response was lost.
            return None

    def release_job(self, otp: str) -> Optional[Dict[str, Any]]:
        url = f"{self.base_url}/agent/release"
        agent_logger.info("Submitting OTP verification request to central backend...")
        try:
            resp = self.session.post(url, json={"otp": otp}, timeout=10)
            if resp.status_code == 200:
                agent_logger.info("Backend verified OTP successfully. Job released.")
                return resp.json()
            else:
                agent_logger.warning(f"Backend OTP verification failed with status {resp.status_code}")
                try:
                    err_payload = resp.json()
                    err_code = err_payload.get("error") or err_payload.get("detail", {}).get("error") or "RELEASE_FAILED"
                    err_msg = err_payload.get("message") or err_payload.get("detail", {}).get("message") or "OTP verification failed."
                except Exception:
                    err_code = "RELEASE_FAILED"
                    err_msg = "OTP verification failed."
                raise OTPReleaseException(message=err_msg, error_code=err_code, status_code=resp.status_code)
        except requests.exceptions.Timeout:
            agent_logger.error("Timeout connecting to backend for OTP release.")
            raise BackendCommunicationException("Backend communication timed out. Please try again.", error_code="NETWORK_TIMEOUT", status_code=504)
        except requests.exceptions.ConnectionError:
            agent_logger.error("FastAPI backend connection refused for OTP release.")
            raise BackendCommunicationException("FastAPI backend is unavailable. Please ensure the backend is running.", error_code="BACKEND_UNAVAILABLE", status_code=503)
        except (OTPReleaseException, BackendCommunicationException):
            raise
        except Exception as e:
            agent_logger.error(f"Unexpected error communicating with backend: {e}")
            raise BackendCommunicationException(str(e), error_code="COMMUNICATION_ERROR", status_code=500)

    def update_job_status(
        self,
        job_id: str,
        status: str,
        cups_job_id: Optional[str] = None,
        error_code: Optional[str] = None,
        message: Optional[str] = None,
        claim_token: Optional[str] = None
    ) -> bool:
        url = f"{self.base_url}/agent/jobs/{job_id}/status"
        payload = {"status": status, "claimToken": claim_token}
        if cups_job_id:
            payload["cupsJobId"] = str(cups_job_id)
        if error_code:
            payload["errorCode"] = error_code
        if message:
            payload["message"] = message

        try:
            resp = self.session.post(url, json=payload, timeout=10)
            if resp.status_code == 200:
                agent_logger.info(f"Updated job {job_id} status to {status}")
                return True
            agent_logger.error(f"Failed to update job status ({resp.status_code}): {resp.text}")
            return False
        except Exception as e:
            agent_logger.error(f"Error reporting job status to backend: {e}")
            return False

backend_client = BackendClient()
