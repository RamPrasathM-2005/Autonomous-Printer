import threading
import time
from typing import Dict, Any, Set
from app.services.file_service import file_service
from app.services.cups_service import cups_service
from app.services.backend_client import backend_client
from app.utils.logging import agent_logger

class PrintService:
    def __init__(self):
        self._lock = threading.Lock()
        self.active_jobs: Set[str] = set()
        self.completed_jobs: Set[str] = set()

    def is_job_active_or_done(self, job_id: str) -> bool:
        with self._lock:
            return job_id in self.active_jobs or job_id in self.completed_jobs

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

        # 1. Resolve and verify local file
        try:
            local_file = file_service.resolve_and_verify_file(storage_key)
        except Exception as e:
            agent_logger.error(f"File lookup failed for job {job_id}: {e}")
            backend_client.update_job_status(
                job_id=job_id,
                status="FAILED",
                error_code="FILE_NOT_FOUND",
                message=str(e)
            )
            return False

        # 2. Submit to CUPS
        try:
            cups_job_id = cups_service.submit_job(local_file, settings)
        except Exception as e:
            agent_logger.error(f"CUPS submission failed for job {job_id}: {e}")
            backend_client.update_job_status(
                job_id=job_id,
                status="FAILED",
                error_code="CUPS_SUBMISSION_FAILED",
                message=str(e)
            )
            return False

        # 3. Report PRINTING status
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

        target_printer = settings.get("cups_printer_name") or settings.get("printer_name")
        cups_status = cups_service.monitor_job(cups_job_id, on_status_callback=status_callback, target_printer=target_printer)
        if cups_status == "COMPLETED":
            backend_client.update_job_status(
                job_id=job_id,
                status="COMPLETED",
                cups_job_id=cups_job_id
            )
            agent_logger.info(f"Successfully finished job {job_id} (CUPS ID {cups_job_id})")
            return True
        elif cups_status == "OUT_OF_PAPER":
            backend_client.update_job_status(
                job_id=job_id,
                status="PRINTING",
                cups_job_id=cups_job_id,
                error_code="OUT_OF_PAPER",
                message="Printer is out of paper. Please load paper into the tray to continue printing."
            )
            return False
        else:
            backend_client.update_job_status(
                job_id=job_id,
                status="FAILED",
                cups_job_id=cups_job_id,
                error_code="PRINT_ERROR",
                message=f"CUPS reported status: {cups_status}"
            )
            return False

print_service = PrintService()
