import threading
import time
from typing import Dict, Any, Set
from app.config import config
from app.services.file_service import file_service
from app.services.cups_service import cups_service
from app.services.backend_client import backend_client
from app.utils.logging import agent_logger

class PrintService:
    def __init__(self):
        self._lock = threading.Lock()
        self.active_jobs: Set[str] = set()
        self.completed_jobs: Set[str] = set()
        self.job_states: Dict[str, Dict[str, Any]] = {}

    def is_job_active_or_done(self, job_id: str) -> bool:
        with self._lock:
            return job_id in self.active_jobs or job_id in self.completed_jobs

    def get_job_state(self, job_id: str) -> Dict[str, Any]:
        with self._lock:
            if job_id in self.job_states:
                return dict(self.job_states[job_id])
            if job_id in self.completed_jobs:
                return {
                    "job_id": job_id,
                    "status": "COMPLETED",
                    "progress": 100,
                    "printer_name": config.PRINTER_NAME,
                    "friendly_printer": "HP LaserJet 400 M401dn",
                    "message": "Print completed. Please collect your document."
                }
            if job_id in self.active_jobs:
                return {
                    "job_id": job_id,
                    "status": "PRINTING",
                    "progress": 70,
                    "printer_name": config.PRINTER_NAME,
                    "friendly_printer": "HP LaserJet 400 M401dn",
                    "message": "Printing in progress..."
                }
            return {
                "job_id": job_id,
                "status": "UNKNOWN",
                "progress": 0,
                "printer_name": config.PRINTER_NAME,
                "friendly_printer": "HP LaserJet 400 M401dn",
                "message": "Waiting for print job..."
            }

    def set_job_state(self, job_id: str, state: Dict[str, Any]):
        with self._lock:
            self.job_states[job_id] = state

    def execute_print_job(self, job: Dict[str, Any]) -> bool:
        job_id = job.get("jobId") or job.get("job_id")
        order_id = job.get("orderId") or job.get("order_id")
        storage_key = job.get("storageKey") or job.get("storage_key")
        settings = job.get("settings", {})

        if not job_id:
            agent_logger.error("execute_print_job called without job_id!")
            return False

        with self._lock:
            if job_id in self.active_jobs:
                agent_logger.warning(f"Job {job_id} is ALREADY PRINTING! Preventing duplicate print.")
                return True
            if job_id in self.completed_jobs:
                agent_logger.warning(f"Job {job_id} has ALREADY COMPLETED! Preventing duplicate print.")
                return True
            self.active_jobs.add(job_id)

        try:
            return self._do_execute(job_id, order_id, storage_key, settings)
        finally:
            with self._lock:
                self.active_jobs.discard(job_id)
                self.completed_jobs.add(job_id)

    def _do_execute(self, job_id: str, order_id: str, storage_key: str, settings: Dict[str, Any]) -> bool:
        agent_logger.info(f"Starting execution of job {job_id} (Order {order_id})")
        raw_printer = settings.get("cups_printer_name") or settings.get("printer_name") or settings.get("selected_printer") or config.PRINTER_NAME
        if any(k in str(raw_printer) for k in ["E9A0F4", "Unit 2", "Printer_2", "central_02"]):
            raw_printer = "HP_LaserJet_400_M401dn_E9A0F4"
            friendly_printer = "HP LaserJet 400 (Unit 2)"
        else:
            raw_printer = "HP_LaserJet_400_M401dn_F36EC0"
            friendly_printer = "HP LaserJet 400 (Unit 1)"

        self.set_job_state(job_id, {
            "job_id": job_id,
            "order_id": order_id,
            "status": "PREPARING",
            "progress": 25,
            "printer_name": raw_printer,
            "friendly_printer": friendly_printer,
            "message": f"Preparing document for {friendly_printer}..."
        })

        local_file = None
        # 1. Resolve and verify local file
        try:
            local_file = file_service.resolve_and_verify_file(storage_key)
        except Exception as e:
            agent_logger.error(f"File lookup failed for job {job_id}: {e}")
            self.set_job_state(job_id, {
                "job_id": job_id,
                "order_id": order_id,
                "status": "FAILED",
                "progress": 0,
                "printer_name": raw_printer,
                "friendly_printer": friendly_printer,
                "message": f"File error: {str(e)}"
            })
            backend_client.update_job_status(
                job_id=job_id,
                status="FAILED",
                error_code="FILE_NOT_FOUND",
                message=str(e)
            )
            return False

        # 2. Submit to CUPS
        self.set_job_state(job_id, {
            "job_id": job_id,
            "order_id": order_id,
            "status": "SENDING",
            "progress": 50,
            "printer_name": raw_printer,
            "friendly_printer": friendly_printer,
            "message": f"Sending job to {friendly_printer}..."
        })
        try:
            cups_job_id = cups_service.submit_job(local_file, settings)
        except Exception as e:
            agent_logger.error(f"CUPS submission failed for job {job_id}: {e}")
            self.set_job_state(job_id, {
                "job_id": job_id,
                "order_id": order_id,
                "status": "FAILED",
                "progress": 0,
                "printer_name": raw_printer,
                "friendly_printer": friendly_printer,
                "message": f"Print error: {str(e)}"
            })
            backend_client.update_job_status(
                job_id=job_id,
                status="FAILED",
                error_code="CUPS_SUBMISSION_FAILED",
                message=str(e)
            )
            return False

        # 3. Report PRINTING status
        self.set_job_state(job_id, {
            "job_id": job_id,
            "order_id": order_id,
            "status": "PRINTING",
            "progress": 75,
            "printer_name": raw_printer,
            "friendly_printer": friendly_printer,
            "message": f"Printing in progress on {friendly_printer}..."
        })
        backend_client.update_job_status(
            job_id=job_id,
            status="PRINTING",
            cups_job_id=cups_job_id
        )

        # 4. Monitor CUPS job completion with paper status reporting
        def status_callback(status: str, error_code: str = None, message: str = None):
            backend_client.update_job_status(
                job_id=job_id,
                status=status,
                cups_job_id=cups_job_id,
                error_code=error_code,
                message=message
            )
            if status == "PRINTING":
                self.set_job_state(job_id, {
                    "job_id": job_id,
                    "order_id": order_id,
                    "status": "PRINTING",
                    "progress": 85,
                    "printer_name": raw_printer,
                    "friendly_printer": friendly_printer,
                    "message": f"Printing pages on {friendly_printer}..."
                })

        def _cleanup_temp_file():
            try:
                if local_file and local_file.exists() and str(file_service.storage_root) in str(local_file):
                    local_file.unlink()
                    agent_logger.info(f"Cleaned up temporary print file on Pi: {local_file}")
            except Exception as ex:
                agent_logger.debug(f"File cleanup ignored error: {ex}")

        cups_status = cups_service.monitor_job(cups_job_id, on_status_callback=status_callback, target_printer=raw_printer)
        if cups_status == "COMPLETED":
            self.set_job_state(job_id, {
                "job_id": job_id,
                "order_id": order_id,
                "status": "COMPLETED",
                "progress": 100,
                "printer_name": raw_printer,
                "friendly_printer": friendly_printer,
                "message": f"Print completed on {friendly_printer}!"
            })
            backend_client.update_job_status(
                job_id=job_id,
                status="COMPLETED",
                cups_job_id=cups_job_id
            )
            agent_logger.info(f"Successfully finished job {job_id} (CUPS ID {cups_job_id})")
            _cleanup_temp_file()
            return True
        elif cups_status == "OUT_OF_PAPER":
            self.set_job_state(job_id, {
                "job_id": job_id,
                "order_id": order_id,
                "status": "OUT_OF_PAPER",
                "progress": 75,
                "printer_name": raw_printer,
                "friendly_printer": friendly_printer,
                "message": f"{friendly_printer} is out of paper. Please load paper."
            })
            backend_client.update_job_status(
                job_id=job_id,
                status="PRINTING",
                cups_job_id=cups_job_id,
                error_code="OUT_OF_PAPER",
                message=f"{friendly_printer} is out of paper. Please load paper into the tray to continue printing."
            )
            return False
        else:
            self.set_job_state(job_id, {
                "job_id": job_id,
                "order_id": order_id,
                "status": "FAILED",
                "progress": 0,
                "printer_name": raw_printer,
                "friendly_printer": friendly_printer,
                "message": f"CUPS error: {cups_status}"
            })
            backend_client.update_job_status(
                job_id=job_id,
                status="FAILED",
                cups_job_id=cups_job_id,
                error_code="PRINT_ERROR",
                message=f"CUPS reported status: {cups_status}"
            )
            _cleanup_temp_file()
            return False

print_service = PrintService()
