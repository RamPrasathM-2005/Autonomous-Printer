import threading
import time
from typing import Set
from app.config import config
from app.services.backend_client import backend_client
from app.services.printer_monitor import printer_monitor
from app.services.print_service import print_service
from app.services.file_service import file_service
from app.utils.logging import agent_logger

class JobPoller:
    def __init__(self):
        self._running = False
        self._poller_thread = None
        self._heartbeat_thread = None
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        # In-memory deduplication set
        self.processing_jobs: Set[str] = set()

    def start(self):
        if self._running:
            return
        self._running = True
        self._stop_event.clear()
        print_service.recover_submissions()

        # Perform startup spool cleanup of orphaned temp files
        try:
            file_service.cleanup_orphaned_files()
        except Exception as err:
            agent_logger.debug(f"Initial spool cleanup note: {err}")

        self._poller_thread = threading.Thread(target=self._poll_loop, daemon=True, name="JobPollerThread")
        self._heartbeat_thread = threading.Thread(target=self._heartbeat_loop, daemon=True, name="HeartbeatThread")

        self._poller_thread.start()
        self._heartbeat_thread.start()
        agent_logger.info(
            f"Background workers active (Poll interval: {config.POLL_INTERVAL_SECONDS}s, "
            f"Heartbeat interval: {config.HEARTBEAT_INTERVAL_SECONDS}s)."
        )

    def stop(self):
        self._running = False
        self._stop_event.set()
        agent_logger.info("Stopping job poller and heartbeat workers...")

    def enqueue_job(self, job):
        job_id = job.get("jobId") or job.get("job_id")
        if not job_id:
            return False
        with self._lock:
            if (job_id in self.processing_jobs or print_service.is_job_active_or_done(job_id) or
                    len(self.processing_jobs) >= config.MAX_CONCURRENT_JOBS):
                return False
            self.processing_jobs.add(job_id)
        threading.Thread(target=self._execute_job_safely, args=(job,), daemon=True,
                         name=f"ExecWorker-{job_id}").start()
        return True

    def _heartbeat_loop(self):
        current_interval = float(config.HEARTBEAT_INTERVAL_SECONDS)
        max_interval = float(config.BACKOFF_MAX_SECONDS * 2)

        while self._running:
            try:
                printer_state, paper_state = printer_monitor.get_printer_status()
                backend_client.flush_status_updates()
                success = backend_client.send_heartbeat(printer_state=printer_state, paper_state=paper_state)
                if success:
                    current_interval = float(config.HEARTBEAT_INTERVAL_SECONDS)
                else:
                    current_interval = min(current_interval * 1.5, max_interval)
            except Exception as e:
                agent_logger.warning(f"Heartbeat network communication issue: {e}")
                current_interval = min(current_interval * 1.5, max_interval)

            self._stop_event.wait(current_interval)

    def _poll_loop(self):
        current_interval = float(config.POLL_INTERVAL_SECONDS)
        max_interval = float(config.BACKOFF_MAX_SECONDS)

        while self._running:
            try:
                jobs = backend_client.poll_jobs()
                current_interval = float(config.POLL_INTERVAL_SECONDS) # Reset backoff on successful query

                for job in jobs:
                    job_id = job.get("jobId") or job.get("job_id")
                    if not job_id:
                        continue

                    self.enqueue_job(job)

            except Exception as e:
                agent_logger.warning(f"Job poller communication issue: {e}")
                current_interval = min(current_interval * 1.5, max_interval)

            self._stop_event.wait(current_interval)

    def _execute_job_safely(self, job: dict):
        job_id = job.get("jobId") or job.get("job_id")
        try:
            print_service.execute_print_job(job)
        finally:
            with self._lock:
                self.processing_jobs.discard(job_id)

job_poller = JobPoller()

