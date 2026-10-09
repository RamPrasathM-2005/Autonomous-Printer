import requests
import shutil
import uuid
from urllib.parse import quote
from pathlib import Path
from typing import List, Dict, Any, Optional
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from app.config import config
from app.utils.errors import BackendCommunicationException, OTPReleaseException
from app.utils.logging import agent_logger
from app.services.job_journal import job_journal

class BackendClient:
    def __init__(self):
        self.base_url = config.BACKEND_URL
        self.token = config.AGENT_TOKEN
        self.session = requests.Session()
        
        # Configure connection pooling and HTTP keep-alive reuse for low CPU overhead
        retries = Retry(
            total=2,
            backoff_factor=0.3,
            status_forcelist=[502, 503, 504],
            raise_on_status=False
        )
        adapter = HTTPAdapter(
            pool_connections=5,
            pool_maxsize=10,
            max_retries=retries
        )
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
        self.session.headers.update({
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "User-Agent": f"PrintAgent/{config.AGENT_ID}",
            "X-Print-Simulation": "true" if config.MOCK_CUPS else "false",
            "X-Station-ID": config.AGENT_ID,
        })


    def send_heartbeat(self, printer_state: str = "READY", paper_state: str = "AVAILABLE", force=False) -> bool:
        url = f"{self.base_url}/agent/heartbeat"
        try:
            from app.services.cups_service import cups_service
            detected = cups_service.get_detected_printers(force=True) if force else cups_service.get_detected_printers()
            payload = {
                "printerState": printer_state,
                "paperState": paper_state,
                "printers": detected
            }
            resp = self.session.post(url, json=payload, timeout=5)
            if resp.status_code == 200:
                if not config.MOCK_CUPS:
                    from app.services.printer_discovery import printer_discovery
                    installed = {p['cups_printer_name'] for p in detected if p['status'] != 'DISCOVERED'}
                    printer_discovery.provision(resp.json().get('assignments', []), installed)
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
            raise BackendCommunicationException(f"Job polling rejected with HTTP {resp.status_code}")

        except Exception as e:
            raise BackendCommunicationException("Job polling unavailable; retrying with backoff") from e

    def claim_job(self, job_id: str) -> bool:
        try:
            resp = self.session.post(f"{self.base_url}/agent/jobs/{job_id}/claim", timeout=10)
            return resp.status_code == 200 and resp.json().get("claimed") is True
        except Exception as exc:
            agent_logger.warning(f"Cannot claim job {job_id}: {exc}")
            return False

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
                    err_code = err_payload.get("error") or err_payload.get("error_code") or err_payload.get("detail", {}).get("error") or "RELEASE_FAILED"
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
        message: Optional[str] = None
    ) -> bool:
        url = f"{self.base_url}/agent/jobs/{job_id}/status"
        payload = {"status": status, "eventId": uuid.uuid4().hex}
        if cups_job_id:
            payload["cupsJobId"] = str(cups_job_id)
        if error_code:
            payload["errorCode"] = error_code
        if message:
            payload["message"] = message

        job_journal.put("pending", job_id, payload)
        return self._deliver_status(job_id, payload)

    def _deliver_status(self, job_id, payload):
        url = f"{self.base_url}/agent/jobs/{job_id}/status"
        try:
            resp = self.session.post(url, json=payload, timeout=10)
            if resp.status_code == 200:
                job_journal.remove("pending", job_id, payload)
                agent_logger.info(f"Updated job {job_id} status to {payload['status']}")
                return True
            agent_logger.error(f"Failed to update job status ({resp.status_code}): {resp.text}")
            return False

        except Exception as e:
            agent_logger.error(f"Error reporting job status to backend: {e}")
            return False

    def flush_status_updates(self):
        for job_id, payload in job_journal.entries("pending"):
            self._deliver_status(job_id, payload)

    def download_file(self, storage_key: str, dest_path: Path) -> bool:
        clean_key = storage_key.lstrip("/\\")
        url = f"{self.base_url}/agent/file/{quote(clean_key, safe='/')}"
        partial_path = dest_path.with_name(dest_path.name + ".part")
        try:
            dest_dir = dest_path.parent
            dest_dir.mkdir(parents=True, exist_ok=True)

            # Prevent SSD exhaustion: Check available disk space before download
            free_space_bytes = shutil.disk_usage(dest_dir).free
            required_space_bytes = config.MIN_FREE_DISK_MB * 1024 * 1024
            if free_space_bytes < required_space_bytes:
                agent_logger.critical(
                    f"Download aborted: Insufficient disk space on station SSD! "
                    f"Free: {free_space_bytes // (1024 * 1024)}MB, Required: {config.MIN_FREE_DISK_MB}MB"
                )
                return False

            resp = self.session.get(url, timeout=60, stream=True)
            if resp.status_code == 200:
                with open(partial_path, "wb") as f:
                    for chunk in resp.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                partial_path.replace(dest_path)
                resp.close()
                agent_logger.info(f"Downloaded document file from backend: {dest_path}")
                return True
            resp.close()
            agent_logger.error(f"Failed to download document from backend ({resp.status_code}): {resp.text[:200]}")
            return False
        except Exception as e:
            agent_logger.error(f"Error downloading document file from backend: {e}")
            return False
        finally:
            partial_path.unlink(missing_ok=True)


backend_client = BackendClient()
