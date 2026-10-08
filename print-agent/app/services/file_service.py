import time
from pathlib import Path
from app.config import config
from app.utils.errors import StorageException
from app.utils.logging import agent_logger

class FileService:
    def __init__(self, storage_root: Path = config.STORAGE_ROOT):
        self.storage_root = storage_root.resolve()
        self.storage_root.mkdir(parents=True, exist_ok=True)
        # Processed jobs directory for sliced/rotated PDFs
        self.processed_dir = (self.storage_root / "processed_jobs").resolve()
        self.processed_dir.mkdir(parents=True, exist_ok=True)

    def resolve_and_verify_file(self, storage_key: str) -> Path:
        """
        Resolves internal storageKey to absolute local path in the agent spool.
        Downloads from central backend if not currently cached locally.
        """
        clean_key = storage_key.lstrip("/\\")
        target_path = (self.storage_root / clean_key).resolve()

        try:
            target_path.relative_to(self.storage_root)
        except ValueError:
            agent_logger.error("Path traversal attempt detected in storage_key.")
            raise StorageException("Path traversal detected in storage key")

        # 1. Check if already present in agent local storage
        if target_path.exists() and target_path.is_file():
            return target_path

        # 2. Check local dev parent folders if they exist (for seamless offline monorepo testing)
        for parent_offset in [
            Path(__file__).resolve().parent.parent.parent.parent / "storage" / clean_key,
            Path(__file__).resolve().parent.parent.parent.parent / "storage" / "documents" / Path(clean_key).name,
            Path(__file__).resolve().parent.parent.parent.parent / "backend" / "storage" / clean_key,
        ]:
            if parent_offset.exists() and parent_offset.is_file():
                agent_logger.info(f"Resolved existing document from development cache: {parent_offset}")
                return parent_offset

        # 3. Production standalone flow: Download from central backend server
        try:
            from app.services.backend_client import backend_client
            agent_logger.info(f"Fetching document {clean_key} from central backend...")
            if backend_client.download_file(clean_key, target_path) and target_path.exists():
                agent_logger.info(f"Successfully retrieved document from backend to {target_path}")
                return target_path
        except Exception as e:
            agent_logger.warning(f"Could not download file from backend: {e}")

        raise StorageException("Document could not be downloaded from the backend. Printing was not started.")

    def cleanup_file(self, file_path: Path | None):
        """Safely removes a temporary print file or processed artifact."""
        if not file_path:
            return
        try:
            resolved = file_path.resolve()
            if resolved.exists() and resolved.is_file():
                resolved.unlink()
                agent_logger.info(f"Cleaned up temporary print file: {resolved}")
        except Exception as err:
            agent_logger.debug(f"Temporary file cleanup notice: {err}")

    def cleanup_orphaned_files(self, max_age_seconds: int = 3600):
        """Scans spool and processed directories to remove orphaned files older than max_age_seconds."""
        now = time.time()
        cleaned_count = 0
        for scan_dir in [self.storage_root, self.processed_dir]:
            if not scan_dir.exists():
                continue
            for item in scan_dir.glob("**/*"):
                if item.is_file() and not item.name.startswith("agent-journal.sqlite3"):
                    try:
                        mtime = item.stat().st_mtime
                        if now - mtime > max_age_seconds:
                            item.unlink()
                            cleaned_count += 1
                    except Exception:
                        pass
        if cleaned_count > 0:
            agent_logger.info(f"Spool maintenance: Cleaned {cleaned_count} orphaned temporary files.")

file_service = FileService()

