from flask import Blueprint, jsonify
from app.config import config

health_bp = Blueprint("health", __name__)

@health_bp.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "healthy",
        "agent_id": config.AGENT_ID,
        "cups_server": config.CUPS_SERVER,
        "printer_name": config.PRINTER_NAME
    }), 200
