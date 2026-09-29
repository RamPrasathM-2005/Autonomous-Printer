import threading
import time
from typing import Set
from app.config import config
from app.services.backend_client import backend_client
from app.services.printer_monitor import printer_monitor
from app.services.print_service import print_service
from app.utils.logging import agent_logger

class JobPoller:
    def __init__(self):
        self._running = False
        self._poller_thread = None
        self._heartbeat_thread = None
        self._lock = threading.Lock()
        # In-memory deduplication set (Section 40)
        self.processing_jobs: Set[str] = set()

    def start(self):
        if self._running:
            return
        self._running = True

        self._poller_thread = threading.Thread(target=self._poll_loop, daemon=True, name="JobPollerThread")
        self._heartbeat_thread = threading.Thread(target=self._heartbeat_loop, daemon=True, name="HeartbeatThread")

        self._poller_thread.start()
        self._heartbeat_thread.start()
        agent_logger.info("Job poller and heartbeat background workers started.")

    def stop(self):
        self._running = False
        agent_logger.info("Stopping job poller and heartbeat workers...")

    def _heartbeat_loop(self):
        while self._running:
            try:
                printer_state, paper_state = printer_monitor.get_printer_status()
                backend_client.send_heartbeat(printer_state=printer_state, paper_state=paper_state)
            except Exception as e:
                agent_logger.error(f"Error in heartbeat loop: {e}")
            time.sleep(config.HEARTBEAT_INTERVAL_SECONDS)

    def _poll_loop(self):
        while self._running:
            try:
                jobs = backend_client.poll_jobs()
                for job in jobs:
                    job_id = job.get("jobId") or job.get("job_id")
                    if not job_id:
                        continue

                    # Section 40: Duplicate polling protection
                    with self._lock:
                        if job_id in self.processing_jobs:
                            continue
                        self.processing_jobs.add(job_id)

                    # Spawn execution worker thread for this job
                    threading.Thread(
                        target=self._execute_job_safely,
                        args=(job,),
                        daemon=True,
                        name=f"ExecWorker-{job_id}"
                    ).start()

            except Exception as e:
                agent_logger.error(f"Error in poll loop: {e}")

            time.sleep(config.POLL_INTERVAL_SECONDS)

    def _execute_job_safely(self, job: dict):
        job_id = job.get("jobId") or job.get("job_id")
        try:
            print_service.execute_print_job(job)
        finally:
            with self._lock:
                self.processing_jobs.discard(job_id)

job_poller = JobPoller()
