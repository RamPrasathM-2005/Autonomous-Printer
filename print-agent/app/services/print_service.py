import hashlib
import hmac
import json
import shutil
from pathlib import Path
from app.config import config
from app.services.file_service import file_service
from app.services.cups_service import cups_service
from app.services.backend_client import backend_client
from app.services.job_journal import journal
from app.utils.logging import agent_logger

class PrintService:
    def _report(self, job, state, cups_id=None, error=None):
        return backend_client.update_job_status(job['jobId'], state, cups_job_id=cups_id,
            error_code=error, claim_token=job['claimToken'], message=error)

    def execute_print_job(self, candidate):
        job = backend_client.claim_job(candidate['jobId'])
        if not job: return False
        if not journal.prepare(job): return False
        job_id = job['jobId']
        spool = Path(config.STATE_ROOT) / (job_id + '.pdf')
        try:
            source = file_service.resolve_and_verify_file(job['storageKey'], job['sha256'], job['fileSize'])
            shutil.copyfile(source, spool)
            with spool.open('rb') as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            if not hmac.compare_digest(digest, job['sha256']):
                raise ValueError('Snapshot integrity mismatch')
        except Exception:
            return self._finish(job, 'FAILED', error='FILE_INTEGRITY')
        if config.MOCK_CUPS and not job.get('allowMock'):
            return self._finish(job, 'FAILED', error='MOCK_FORBIDDEN')
        if not config.MOCK_CUPS and not cups_service.has_pycups:
            return self._finish(job, 'FAILED', error='PRINTER_UNAVAILABLE')
        try:
            cups_id = cups_service.submit_job(spool, job['settings'], allow_mock=job.get('allowMock', False))
            journal.update(job_id, 'SUBMITTED', cups_id)
            self._report(job, 'PRINTING', cups_id)
        except Exception:
            return self._finish(job, 'FAILED', error='SUBMISSION_UNKNOWN_OPERATOR_REVIEW')
        return self.monitor(job, cups_id)

    def _finish(self, job, outcome, cups_id=None, error=None):
        journal.update(job['jobId'], 'FINAL', cups_id, json.dumps({'status': outcome, 'error': error}))
        if self._report(job, outcome, cups_id, error):
            journal.update(job['jobId'], 'DONE', cups_id)
            (Path(config.STATE_ROOT) / (job['jobId'] + '.pdf')).unlink(missing_ok=True)
            return outcome == 'COMPLETED'
        return False

    def monitor(self, job, cups_id):
        status = cups_service.monitor_job(cups_id)
        if status == 'COMPLETED':
            return self._finish(job, 'COMPLETED', cups_id)
        if status == 'FAILED':
            return self._finish(job, 'FAILED', cups_id, 'PRINTER_FAILED_OPERATOR_REVIEW')
        if status == 'UNKNOWN':
            agent_logger.error('Printer outcome requires review for job %s', job['jobId'])
        return False  # Pending monitoring, never an inferred success or blind resubmission.

    def recover(self):
        for record in journal.pending():
            job = json.loads(record['payload'])
            if record['state'] == 'PREPARED':
                self._finish(job, 'FAILED', error='SUBMISSION_UNKNOWN_OPERATOR_REVIEW')
            elif record['state'] == 'SUBMITTED':
                self.monitor(job, record['cups_id'])
            elif record['state'] == 'FINAL':
                outcome = json.loads(record['outcome'])
                self._finish(job, outcome['status'], record['cups_id'], outcome['error'])

print_service = PrintService()
