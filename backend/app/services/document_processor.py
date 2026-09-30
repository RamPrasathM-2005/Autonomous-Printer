import json
import os
import subprocess
import sys
import uuid
from pathlib import Path
from app.services.storage_service import storage_service
from app.utils.common import fail

def process_document(payload):
    token = uuid.uuid4().hex
    request = storage_service.get_temp_dir() / (token + '.json')
    response = storage_service.get_temp_dir() / (token + '.result')
    try:
        request.write_text(json.dumps(payload), encoding='utf-8')
        # No application secrets or Python import-path overrides in parser children.
        environment = {k: v for k, v in os.environ.items()
                       if k.upper() in ('SYSTEMROOT', 'WINDIR', 'PATH', 'TEMP', 'TMP', 'LANG', 'LC_ALL')}
        child = subprocess.run([sys.executable, '-I', str(Path(__file__).with_name('document_worker.py')),
            str(request), str(response)], cwd=storage_service.get_temp_dir(), env=environment,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=45)
        if child.returncode or not response.exists():
            fail('INVALID_FILE', 'Document could not be safely processed.')
        result = json.loads(response.read_text())
        if 'error' in result:
            fail('INVALID_FILE', 'Document could not be safely processed.')
        return result['pages']
    except subprocess.TimeoutExpired:
        fail('DOCUMENT_TIMEOUT', 'Document processing exceeded the allowed time.', 422)
    finally:
        request.unlink(missing_ok=True)
        response.unlink(missing_ok=True)
