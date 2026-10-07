import os
import sys
from pathlib import Path

# Ensure print-agent root is in sys.path when executed directly via `py app/main.py`
ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from flask import Flask
from app.config import config
from app.routes.health import health_bp
from app.routes.local import local_bp
from app.routes.kiosk import kiosk_bp
from app.services.job_poller import job_poller
from app.utils.logging import agent_logger

def create_app() -> Flask:
    app = Flask(__name__)

    @app.after_request
    def add_cors_headers(response):
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept"
        return response

    @app.route("/", defaults={"path": ""}, methods=["OPTIONS"])
    @app.route("/<path:path>", methods=["OPTIONS"])
    def handle_options(path=""):
        response = app.make_default_options_response()
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept"
        return response

    # Register blueprints
    app.register_blueprint(health_bp)
    app.register_blueprint(local_bp)
    app.register_blueprint(kiosk_bp)

    return app

import signal

def run_agent():
    def handle_shutdown(signum, frame):
        agent_logger.info(f"Received termination signal ({signum}). Initiating graceful agent shutdown...")
        job_poller.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_shutdown)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, handle_shutdown)

    agent_logger.info(f"Starting Flask Print Agent for station: {config.AGENT_ID} on port {config.PORT}")
    # Start background job poller and heartbeat
    job_poller.start()

    app = create_app()
    app.run(host="0.0.0.0", port=config.PORT, debug=False, threaded=True)

if __name__ == "__main__":
    run_agent()

