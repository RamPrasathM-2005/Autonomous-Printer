import os
import sys
from pathlib import Path

# Ensure print-agent root is in sys.path when executed directly via `py app/main.py`
ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from flask import Flask, request, jsonify
import ipaddress
from urllib.parse import urlsplit
from app.config import config
from app.routes.health import health_bp
from app.routes.local import local_bp
from app.routes.kiosk import kiosk_bp
from app.services.job_poller import job_poller
from app.utils.logging import agent_logger

def create_app() -> Flask:
    app = Flask(__name__)
    app.config['MAX_CONTENT_LENGTH'] = 65536

    @app.before_request
    def protect_local_controls():
        if not request.path.startswith('/local/'):
            return
        try:
            loopback = ipaddress.ip_address(request.remote_addr or '').is_loopback
        except ValueError:
            loopback = False
        if not loopback:
            return jsonify(error='LOCAL_ACCESS_REQUIRED', message='Use the station touchscreen.'), 403
        if urlsplit(request.host_url).hostname not in {'localhost', '127.0.0.1', '::1'}:
            return jsonify(error='HOST_REJECTED'), 403
        origin = request.headers.get('Origin')
        if origin and origin != request.host_url.rstrip('/'):
            return jsonify(error='ORIGIN_REJECTED'), 403
        if request.headers.get('Sec-Fetch-Site') == 'cross-site':
            return jsonify(error='ORIGIN_REJECTED'), 403
        if request.method in ('POST', 'PUT', 'PATCH', 'DELETE') and not request.is_json:
            return jsonify(error='JSON_REQUIRED'), 415

    @app.after_request
    def add_cors_headers(response):
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Referrer-Policy'] = 'no-referrer'
        response.headers['Cache-Control'] = 'no-store'
        origin = request.headers.get("Origin", "")
        allowed = {request.host_url.rstrip("/")} | set(filter(None, os.getenv("ALLOWED_ORIGINS", "").split(",")))
        if origin in allowed:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept"
        return response

    @app.route("/", defaults={"path": ""}, methods=["OPTIONS"])
    @app.route("/<path:path>", methods=["OPTIONS"])
    def handle_options(path=""):
        response = app.make_default_options_response()
        origin = request.headers.get("Origin", "")
        allowed = {request.host_url.rstrip("/")} | set(filter(None, os.getenv("ALLOWED_ORIGINS", "").split(",")))
        if origin in allowed:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
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
    if not config.AGENT_TOKEN or 'CHANGE_ME' in config.AGENT_TOKEN or config.AGENT_TOKEN == 'test-agent-device-token-secret':
        raise RuntimeError("Configure AGENT_TOKEN with the unique token generated when registering this station in admin.")
    from app.services.cups_service import cups_service
    if not config.MOCK_CUPS and not cups_service.has_pycups:
        raise RuntimeError("Physical printing requires pycups for reliable job status. Install python3-cups or the agent requirements; use MOCK_CUPS=true only for simulation.")
    # Start background job poller and heartbeat
    job_poller.start()

    app = create_app()
    from waitress import serve
    try:
        serve(app, host=os.getenv("HOST", "127.0.0.1"), port=config.PORT, threads=4,
              connection_limit=32, channel_timeout=30, max_request_body_size=65536)
    finally:
        job_poller.stop()

if __name__ == "__main__":
    run_agent()

