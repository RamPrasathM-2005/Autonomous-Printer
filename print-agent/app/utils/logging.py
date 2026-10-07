import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path
from app.config import config

def setup_agent_logger(name: str = "PrintAgent") -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    if not logger.handlers:
        formatter = logging.Formatter(
            fmt="[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )

        # Standard console handler for systemd journald capture
        stream_handler = logging.StreamHandler(sys.stdout)
        stream_handler.setFormatter(formatter)
        logger.addHandler(stream_handler)

        # SSD protection: Bounded rotating file handler
        try:
            log_dir = Path(config.LOG_DIR)
            log_dir.mkdir(parents=True, exist_ok=True)
            log_file = log_dir / "print-agent.log"
            file_handler = RotatingFileHandler(
                log_file,
                maxBytes=5 * 1024 * 1024, # 5 MB cap per log segment
                backupCount=3,            # Retain maximum 3 historical segments
                encoding="utf-8"
            )
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
        except Exception as err:
            logger.warning(f"Could not initialize rotating log file: {err}")

    return logger

agent_logger = setup_agent_logger()

