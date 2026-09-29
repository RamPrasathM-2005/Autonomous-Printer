import time
from typing import Dict, Any
from app.services.file_service import file_service
from app.services.cups_service import cups_service
from app.services.backend_client import backend_client
from app.utils.logging import agent_logger

class PrintService:
    @staticmethod
    def execute_print_job(job: Dict[str, Any]) -> bool:
        job_id = job.get("jobId") or job.get("job_id")
        order_id = job.get("orderId") or job.get("order_id")
        storage_key = job.get("storageKey") or job.get("storage_key")
        settings = job.get("settings", {})

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

        # 4. Monitor CUPS job completion
        cups_status = cups_service.monitor_job(cups_job_id)
        if cups_status == "COMPLETED":
            backend_client.update_job_status(
                job_id=job_id,
                status="COMPLETED",
                cups_job_id=cups_job_id
            )
            agent_logger.info(f"Successfully finished job {job_id} (CUPS ID {cups_job_id})")
            return True
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
