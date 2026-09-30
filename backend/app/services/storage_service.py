import os
from pathlib import Path
from app.config.settings import settings
from app.utils.file_security import resolve_safe_storage_path

class StorageService:
    def __init__(self, storage_root=None):
        path = Path(storage_root or settings.STORAGE_ROOT)
        base = Path(__file__).resolve().parents[2]
        self.storage_root = (base / path).resolve() if not path.is_absolute() else path.resolve()
        self._ensure_directories()

    def _ensure_directories(self):
        for name in ('documents', 'temp'):
            (self.storage_root / name).mkdir(parents=True, exist_ok=True)

    def get_temp_dir(self):
        return self.storage_root / 'temp'

    def resolve_storage_key(self, storage_key):
        return resolve_safe_storage_path(self.storage_root, storage_key)

    def save_file_atomically(self, source_temp_path, target_storage_key):
        target = self.resolve_storage_key(target_storage_key)
        target.parent.mkdir(parents=True, exist_ok=True)
        os.replace(source_temp_path, target)
        return target

    def delete_file(self, storage_key):
        target = self.resolve_storage_key(storage_key)
        if not target.exists():
            return False
        target.unlink()  # Propagate failure; never mark undeleted data as deleted.
        return True

storage_service = StorageService()
