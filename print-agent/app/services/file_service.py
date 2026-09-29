from pathlib import Path
from app.config import config
from app.utils.errors import StorageException
from app.utils.logging import agent_logger

class FileService:
    def __init__(self, storage_root: Path = config.STORAGE_ROOT):
        self.storage_root = storage_root.resolve()

    def resolve_and_verify_file(self, storage_key: str) -> Path:
        """
        Resolves internal storageKey to absolute local path and validates against path traversal.
        Ensures the file exists and is accessible.
        """
        clean_key = storage_key.lstrip("/\\")
        target_path = (self.storage_root / clean_key).resolve()

        try:
            target_path.relative_to(self.storage_root)
        except ValueError:
            agent_logger.error("Path traversal attempt detected in storage_key.")
            raise StorageException("Invalid storage key: directory traversal detected.")

        if not target_path.exists() or not target_path.is_file():
            agent_logger.error(f"Local document file not found at: {target_path}")
            raise StorageException(f"Local file not found for storage key.")

        return target_path

file_service = FileService()
