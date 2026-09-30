import requests
from typing import List, Dict, Any, Optional
from app.config import config
from app.utils.errors import BackendCommunicationException
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
        try:
            resp = self.session.post(url, json={"otp": otp}, timeout=10)
            if resp.status_code == 200:
                return resp.json()
            else:
                agent_logger.warning(f"OTP release failed ({resp.status_code}): {resp.text}")
                return None
        except Exception as e:
            agent_logger.error(f"Failed to submit OTP to backend: {e}")
            raise BackendCommunicationException(str(e))

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
