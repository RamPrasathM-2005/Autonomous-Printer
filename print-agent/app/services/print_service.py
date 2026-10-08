import threading
import time
from collections import OrderedDict
from typing import Dict, Any, Set
from app.config import config
from app.services.file_service import file_service
from app.services.cups_service import cups_service
from app.services.backend_client import backend_client
from app.utils.logging import agent_logger
from app.services.job_journal import job_journal

class BoundedSet:
    """Memory-safe LRU set for 24/7 Raspberry Pi operation."""
    def __init__(self, maxsize: int = 100):
        self.maxsize = maxsize
        self._items = OrderedDict()

    def add(self, item: str):
        self._items[item] = None
        if len(self._items) > self.maxsize:
            self._items.popitem(last=False)

    def discard(self, item: str):
        self._items.pop(item, None)

    def __contains__(self, item: str) -> bool:
        return item in self._items

    def __len__(self) -> int:
        return len(self._items)

class BoundedDict:
    """Memory-safe LRU dictionary for 24/7 Raspberry Pi operation."""
    def __init__(self, maxsize: int = 100):
        self.maxsize = maxsize
        self._data = OrderedDict()

    def __setitem__(self, key: str, value: Any):
        self._data[key] = value
        if len(self._data) > self.maxsize:
            self._data.popitem(last=False)

    def __getitem__(self, key: str) -> Any:
        return self._data[key]

    def __contains__(self, key: str) -> bool:
        return key in self._data

    def get(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, default)

    def to_dict(self, key: str) -> Dict[str, Any]:
        return dict(self._data.get(key, {}))

class PrintService:
    def __init__(self):
        self._lock = threading.Lock()
        self.active_jobs: Set[str] = set()
        self.completed_jobs = BoundedSet(maxsize=config.MAX_CACHE_JOBS)
        self.job_states = BoundedDict(maxsize=config.MAX_CACHE_JOBS)


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
                    "friendly_printer": config.PRINTER_NAME or "Department printer",
                    "message": "Print completed. Please collect your document."
                }
            if job_id in self.active_jobs:
                return {
                    "job_id": job_id,
                    "status": "PRINTING",
                    "progress": 70,
                    "printer_name": config.PRINTER_NAME,
                    "friendly_printer": config.PRINTER_NAME or "Department printer",
                    "message": "Printing in progress..."
                }
            return {
                "job_id": job_id,
                "status": "UNKNOWN",
                "progress": 0,
                "printer_name": config.PRINTER_NAME,
                "friendly_printer": config.PRINTER_NAME or "Department printer",
                "message": "Waiting for print job..."
            }

    def set_job_state(self, job_id: str, state: Dict[str, Any]):
        with self._lock:
            previous = self.job_states.get(job_id, {})
            # Carry correlation information through abbreviated recovery/error updates.
            state = {**previous, **state}
            self.job_states[job_id] = state
        agent_logger.info("Print job state changed", extra={
            "job_id": job_id, "order_id": state.get("order_id"),
            "printer_id": state.get("printer_name"), "device_id": config.AGENT_ID,
            "department_id": state.get("department_id"),
            "previous_state": previous.get("status"), "state": state.get("status"),
        })

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

        succeeded = False
        try:
            if not backend_client.claim_job(job_id):
                agent_logger.warning(f"Job {job_id} was not claimed; no document will be submitted.")
                return False
            succeeded = self._do_execute(job_id, order_id, storage_key, settings)
            return succeeded
        finally:
            with self._lock:
                self.active_jobs.discard(job_id)
                if succeeded:
                    self.completed_jobs.add(job_id)

    def recover_submissions(self):
        for job_id, entry in job_journal.entries("submissions"):
            with self._lock:
                if job_id in self.active_jobs:
                    continue
                self.active_jobs.add(job_id)
            threading.Thread(target=self._resume_submission, args=(job_id, entry), daemon=True).start()

    def _resume_submission(self, job_id, entry):
        try:
            cups_id = entry["cups_job_id"]
            result = cups_service.monitor_job(cups_id, target_printer=entry["printer_name"])
            status = "COMPLETED" if result == "COMPLETED" else ("FAILED" if result == "FAILED" else "PRINTING")
            backend_client.update_job_status(job_id, status, cups_job_id=cups_id,
                error_code=None if status == "COMPLETED" else result)
            self.set_job_state(job_id, {"job_id": job_id, "status": status,
                "progress": 100 if status == "COMPLETED" else 75, "printer_name": entry["printer_name"]})
            if status in ("COMPLETED", "FAILED"):
                job_journal.remove("submissions", job_id)
        except Exception:
            # Preserve the journal so a later poll can resume observation.
            agent_logger.exception("Failed to resume CUPS monitoring for job %s", job_id)
        finally:
            with self._lock:
                self.active_jobs.discard(job_id)

    def _do_execute(self, job_id: str, order_id: str, storage_key: str, settings: Dict[str, Any]) -> bool:
        started = time.monotonic()
        agent_logger.info(f"Starting execution of job {job_id} (Order {order_id})")
        raw_printer = settings.get("cups_printer_name") or settings.get("printer_name") or settings.get("selected_printer") or config.PRINTER_NAME
        friendly_printer = settings.get("printer_name") or raw_printer or "Station printer"

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
        prepared_file = None
        try:
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
                try:
                    job_journal.put("submissions", job_id, {"cups_job_id": cups_job_id, "printer_name": raw_printer,
                                                           "order_id": order_id})
                except Exception:
                    # CUPS already accepted the document. A journal write failure
                    # must never convert that into a refundable submission failure.
                    agent_logger.exception("CUPS accepted job but its recovery journal could not be saved",
                                           extra={"job_id": job_id, "order_id": order_id, "cups_job_id": cups_job_id})
                prepared_file = getattr(cups_service, "last_prepared_file", None)
            except Exception as e:
                agent_logger.exception("CUPS submission failed for job %s", job_id)
                if getattr(e, "error_code", "") == "SUBMISSION_UNKNOWN":
                    self.set_job_state(job_id, {"job_id": job_id, "status": "PRINTING", "progress": 50,
                        "printer_name": raw_printer, "message": "Submission outcome unknown. Ask the attendant to inspect CUPS."})
                    backend_client.update_job_status(job_id, "PRINTING", error_code="SUBMISSION_UNKNOWN", message=str(e))
                    return False
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
                        "status": "OUT_OF_PAPER" if error_code == "OUT_OF_PAPER" else "PRINTING",
                        "progress": 85,
                        "printer_name": raw_printer,
                        "friendly_printer": friendly_printer,
                        "message": message or f"Printing pages on {friendly_printer}..."
                    })

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
                job_journal.remove("submissions", job_id)
                agent_logger.info(f"Successfully finished job {job_id} (CUPS ID {cups_job_id})")
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
            elif cups_status == "STATUS_UNKNOWN":
                self.set_job_state(job_id, {
                    "job_id": job_id, "order_id": order_id, "status": "PRINTING",
                    "progress": 75, "printer_name": raw_printer,
                    "friendly_printer": friendly_printer,
                    "message": "Printer outcome is unknown. Ask the attendant to inspect CUPS before retrying."
                })
                backend_client.update_job_status(job_id, "PRINTING", cups_job_id=cups_job_id,
                    error_code="STATUS_UNKNOWN", message="CUPS outcome could not be confirmed. Inspect the queue before retrying.")
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
                job_journal.remove("submissions", job_id)
                return False
        finally:
            agent_logger.info("Print execution finished", extra={"job_id": job_id, "order_id": order_id,
                "printer_id": raw_printer, "duration_ms": round((time.monotonic() - started) * 1000),
                "state": self.get_job_state(job_id).get("status")})
            # SSD Protection: Guaranteed cleanup of downloaded and prepared spool artifacts
            prepared_file = getattr(cups_service, "last_prepared_file", None) or prepared_file
            if local_file and local_file.is_relative_to(file_service.storage_root):
                file_service.cleanup_file(local_file)
            if prepared_file:
                file_service.cleanup_file(prepared_file)


print_service = PrintService()
