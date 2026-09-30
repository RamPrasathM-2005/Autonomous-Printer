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

    from flask import request, jsonify
    app.config['MAX_CONTENT_LENGTH'] = 4096

    @app.before_request
    def check_browser_origin():
        origin = request.headers.get('Origin')
        local_origins = {f'http://127.0.0.1:{config.PORT}', f'http://localhost:{config.PORT}'}
        if origin and origin not in config.ALLOWED_ORIGINS and origin not in local_origins:
            return jsonify({'error': 'ORIGIN_DENIED'}), 403
        if request.host.split(':')[0] not in ('localhost', '127.0.0.1'):
            return jsonify({'error': 'HOST_DENIED'}), 403

    @app.after_request
    def headers(response):
        origin = request.headers.get('Origin')
        if origin in config.ALLOWED_ORIGINS:
            response.headers['Access-Control-Allow-Origin'] = origin
            response.headers['Vary'] = 'Origin'
            response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
            response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response.headers['Cache-Control'] = 'no-store'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['Referrer-Policy'] = 'no-referrer'
        response.headers['Content-Security-Policy'] = (
            "default-src 'none'; script-src 'self'; style-src 'self'; "
            "connect-src 'self'; img-src 'self'; form-action 'self'; "
            "frame-ancestors 'none'; base-uri 'none'"
        )
        return response

    # Register blueprints
    app.register_blueprint(health_bp)
    app.register_blueprint(local_bp)
    app.register_blueprint(kiosk_bp)

    return app

def run_agent():
    if len(config.AGENT_TOKEN) < 32:
        raise RuntimeError('Configure a random AGENT_TOKEN of at least 32 characters')
    config.STATE_ROOT.mkdir(parents=True, exist_ok=True)
    lock_file = open(config.STATE_ROOT / '.agent.lock', 'a+b')
    lock_file.seek(0)
    if os.name == 'nt':
        import msvcrt
        msvcrt.locking(lock_file.fileno(), msvcrt.LK_NBLCK, 1)
    else:
        import fcntl
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)

    agent_logger.info(f"Starting Flask Print Agent for station: {config.AGENT_ID}")
    # Start background job poller and heartbeat
    job_poller.start()

    app = create_app()
    # Local only - not exposed publicly
    app.run(host="127.0.0.1", port=config.PORT, debug=False)

if __name__ == "__main__":
    run_agent()
