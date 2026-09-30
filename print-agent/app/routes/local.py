import re
from collections import deque
from threading import Lock
from time import monotonic

from flask import Blueprint, current_app, jsonify, request
from app.config import config
from app.services.printer_monitor import printer_monitor
from app.services.job_poller import job_poller
from app.services.backend_client import backend_client
from app.utils.errors import BackendCommunicationException, OTPReleaseException

local_bp = Blueprint("local", __name__, url_prefix="/local")
_attempt_lock = Lock()


@local_bp.route("/status", methods=["GET", "OPTIONS"])
def get_local_status():
    if request.method == "OPTIONS":
        return "", 200
    printer_state, paper_state = printer_monitor.get_printer_status()
    return jsonify({
        "agent_id": config.AGENT_ID,
        "printer_name": config.PRINTER_NAME,
        "printer_state": printer_state,
        "paper_state": paper_state,
        "active_jobs_count": len(job_poller.processing_jobs),
        "mock_printing": config.MOCK_CUPS,
    }), 200


@local_bp.route("/release", methods=["POST", "OPTIONS"])
def local_station_otp_release():
    if request.method == "OPTIONS":
        return "", 200
    # Supplemental local throttle; the backend enforces a persistent station limit.
    with _attempt_lock:
        attempts = current_app.extensions.setdefault("release_attempts", deque())
        now = monotonic()
        while attempts and now - attempts[0] >= 60:
            attempts.popleft()
        if len(attempts) >= 10:
            return jsonify(error="TOO_MANY_ATTEMPTS", message="Too many attempts. Try again later."), 429
        attempts.append(now)

    data = request.get_json(silent=True)
    otp = data.get("otp") if isinstance(data, dict) else None
    if not isinstance(otp, str) or not re.fullmatch(r"[0-9]{6}", otp):
        return jsonify(error="INVALID_OTP", message="Enter a six-digit release code."), 400
    printer_state, _ = printer_monitor.get_printer_status()
    if printer_state == "ERROR":
        return jsonify(error="PRINTER_OFFLINE", message="Printer unavailable. Contact the attendant."), 503
    try:
        release_data = backend_client.release_job(otp)
    except OTPReleaseException as exc:
        messages = {
            "INVALID_OTP": "Invalid release code.",
            "OTP_EXPIRED": "Release code expired. Check your order status.",
            "ORDER_ALREADY_COMPLETED": "This order has already been printed.",
            "ORDER_PRINTING": "This order is already printing.",
            "OTP_ALREADY_USED": "Release code already used. Check your order status.",
            "TOO_MANY_ATTEMPTS": "Too many attempts. Try again later.",
            "RATE_LIMITED": "Too many attempts. Try again later.",
        }
        status = exc.status_code if exc.status_code in (400, 403, 404, 409, 410, 422, 429) else 400
        return jsonify(error=exc.error_code, message=messages.get(exc.error_code, "Unable to release this order. Check your order status.")), status
    except BackendCommunicationException as exc:
        status = 504 if exc.status_code == 504 else 503
        return jsonify(error="BACKEND_UNAVAILABLE", message="Service unavailable. Check your order status."), status
    if not isinstance(release_data, dict) or not release_data.get("jobId"):
        return jsonify(error="RELEASE_FAILED", message="Unable to release this order. Check your order status."), 400
    # Only the polling worker can atomically claim, journal and submit a job.
    # Never return file storage keys or imply that paper has already printed.
    return jsonify(status="RELEASED", message="Print released.",
                   jobId=release_data["jobId"], orderId=release_data.get("orderId")), 200
