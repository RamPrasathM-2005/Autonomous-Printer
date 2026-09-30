import hashlib
import hmac
from pathlib import Path, PureWindowsPath
from app.config import config
from app.utils.errors import StorageException

class FileService:
    def __init__(self, storage_root=None):
        self.storage_root = Path(storage_root or config.STORAGE_ROOT).resolve()

    def resolve_and_verify_file(self, storage_key, sha256=None, file_size=None):
        if (not isinstance(storage_key, str) or not storage_key or ':' in storage_key or
                PureWindowsPath(storage_key).drive or storage_key.startswith(('/', "\\")) or
                '..' in storage_key.replace("\\", '/').split('/')):
            raise StorageException('Invalid storage key')
        target = (self.storage_root / storage_key).resolve()
        if not target.is_relative_to(self.storage_root) or not target.is_file():
            raise StorageException('Document not found within configured storage')
        if not sha256 or not isinstance(file_size, int) or target.stat().st_size != file_size:
            raise StorageException('Document size or integrity metadata mismatch')
        with target.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        if not hmac.compare_digest(digest, sha256):
            raise StorageException('Document hash mismatch')
        return target

file_service = FileService()
