import threading
import time
from app.config import config
from app.services.backend_client import backend_client
from app.services.printer_monitor import printer_monitor
from app.services.print_service import print_service
from app.utils.logging import agent_logger

class JobPoller:
    def __init__(self):
        self._running = False
        self.processing_jobs = set()

    def start(self):
        if self._running: return
        self._running = True
        threading.Thread(target=self._heartbeat_loop, daemon=True).start()
        threading.Thread(target=self._poll_loop, daemon=True).start()

    def stop(self):
        self._running = False

    def _heartbeat_loop(self):
        while self._running:
            try:
                printer, paper = printer_monitor.get_printer_status()
                backend_client.send_heartbeat(printer, paper)
            except Exception:
                agent_logger.exception('Heartbeat failed')
            time.sleep(config.HEARTBEAT_INTERVAL_SECONDS)

    def _poll_loop(self):
        while self._running:
            try:
                # Single execution loop avoids release/poll races; DB claim handles multiple agents.
                print_service.recover()
                for job in backend_client.poll_jobs():
                    self.processing_jobs.add(job['jobId'])
                    try: print_service.execute_print_job(job)
                    finally: self.processing_jobs.discard(job['jobId'])
            except Exception:
                agent_logger.exception('Job processing failed')
            time.sleep(config.POLL_INTERVAL_SECONDS)

job_poller = JobPoller()
