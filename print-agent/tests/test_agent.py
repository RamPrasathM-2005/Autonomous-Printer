import hashlib
import pytest
from unittest.mock import patch
from app.config import config
from app.services.cups_service import cups_service
from app.services.file_service import FileService
from app.services.job_journal import JobJournal
from app.services.print_service import print_service
from app.utils.errors import StorageException, CupsException

def test_health_endpoint(agent_client):
    assert agent_client.get('/health').status_code == 200

def test_local_status_endpoint(agent_client):
    assert agent_client.get('/local/status').status_code == 200

def test_cups_options_mapping():
    result=cups_service.build_cups_options({'copies':3,'pageRange':'1-3,5','colour':True,
        'sides':'two-sided-long-edge','paperSize':'A4','orientation':'landscape'})
    assert result['copies']=='3' and result['page-ranges']=='1-3,5'
    assert result['print-color-mode']=='color' and result['orientation-requested']=='4'

def test_mock_requires_explicit_backend_permission(tmp_path,monkeypatch):
    monkeypatch.setattr(cups_service,'mock_mode',True)
    path=tmp_path/'doc.pdf';path.write_bytes(b'pdf')
    with pytest.raises(CupsException):cups_service.submit_job(path,{},allow_mock=False)
    assert cups_service.submit_job(path,{},allow_mock=True).startswith('mock-')

def test_missing_printer_never_simulates(tmp_path,monkeypatch):
    monkeypatch.setattr(cups_service,'mock_mode',False)
    monkeypatch.setattr(cups_service,'has_pycups',False)
    with pytest.raises(CupsException):cups_service.submit_job(tmp_path/'doc.pdf',{})
    assert cups_service.monitor_job('123')=='UNKNOWN'

@pytest.mark.parametrize('key',['../outside.pdf','/etc/passwd','C:/secret','documents/a.pdf:stream'])
def test_path_escape_rejected(tmp_path,key):
    with pytest.raises(StorageException):FileService(tmp_path).resolve_and_verify_file(key,'a'*64,1)

def test_missing_document_never_fabricated(tmp_path):
    with pytest.raises(StorageException):FileService(tmp_path).resolve_and_verify_file('missing.pdf','a'*64,1)
    assert not (tmp_path/'missing.pdf').exists()

def test_hash_and_size_required(tmp_path):
    path=tmp_path/'file.pdf';path.write_bytes(b'test')
    service=FileService(tmp_path)
    with pytest.raises(StorageException):service.resolve_and_verify_file('file.pdf')
    with pytest.raises(StorageException):service.resolve_and_verify_file('file.pdf','0'*64,4)
    with pytest.raises(StorageException):service.resolve_and_verify_file('file.pdf',hashlib.sha256(b'test').hexdigest(),5)
    assert service.resolve_and_verify_file('file.pdf',hashlib.sha256(b'test').hexdigest(),4)==path

def test_local_release_only_queues_job(agent_client):
    with patch('app.routes.local.backend_client.release_job',return_value={'jobId':'job_1','status':'RELEASED'}), patch.object(print_service,'execute_print_job') as submit:
        assert agent_client.post('/local/release',json={'otp':'123456'}).status_code==200
        submit.assert_not_called()

def test_untrusted_browser_origin_rejected(agent_client):
    assert agent_client.post('/local/release',json={'otp':'123456'},headers={'Origin':'https://evil.example'}).status_code==403

def test_durable_deduplication(tmp_path,monkeypatch):
    monkeypatch.setattr(config,'STATE_ROOT',tmp_path)
    first=JobJournal();job={'jobId':'job1','claimToken':'secret'}
    assert first.prepare(job)
    second=JobJournal()
    assert not second.prepare(job)
    second.update('job1','DONE','123')
    assert second.pending()==[]
    with second.connect() as db:
        assert 'secret' not in db.execute('SELECT payload FROM jobs').fetchone()[0]

def test_crash_before_confirmed_submission_never_reprints(tmp_path,monkeypatch):
    monkeypatch.setattr(config,'STATE_ROOT',tmp_path)
    journal=JobJournal();journal.prepare({'jobId':'job1','claimToken':'x'*40})
    monkeypatch.setattr('app.services.print_service.journal',journal)
    with patch('app.services.print_service.backend_client.update_job_status',return_value=True) as report, patch.object(cups_service,'submit_job') as submit:
        print_service.recover()
        submit.assert_not_called()
        assert report.call_args.kwargs['error_code']=='SUBMISSION_UNKNOWN_OPERATOR_REVIEW'

def test_processing_is_not_failed_or_completed(monkeypatch):
    with patch.object(cups_service,'monitor_job',return_value='PROCESSING'), patch.object(print_service,'_finish') as finish:
        assert not print_service.monitor({'jobId':'job1'},'123')
        finish.assert_not_called()
