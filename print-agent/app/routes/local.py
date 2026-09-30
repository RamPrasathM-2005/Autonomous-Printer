import time
import re
from collections import deque
from flask import Blueprint, jsonify, request
from app.config import config
from app.services.printer_monitor import printer_monitor
from app.services.job_poller import job_poller
from app.services.backend_client import backend_client
from app.services.print_service import print_service
from app.utils.errors import BackendCommunicationException, OTPReleaseException
from app.utils.logging import agent_logger

local_bp = Blueprint("local", __name__, url_prefix="/local")

# Rate limiting for local kiosk attempts (Sliding window of timestamps)
_recent_attempts = deque()
MAX_LOCAL_ATTEMPTS = 10
LOCAL_WINDOW_SECONDS = 60

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
        "active_jobs_count": len(job_poller.processing_jobs)
    }), 200

@local_bp.route("/release", methods=["POST", "OPTIONS"])
def local_station_otp_release():
    if request.method == "OPTIONS":
        return "", 200
    """
    Endpoint for station touchscreen/keypad input.
    Receives OTP entered physically at the print kiosk.
    """
    now = time.time()
    # Clean sliding window
    while _recent_attempts and _recent_attempts[0] < now - LOCAL_WINDOW_SECONDS:
        _recent_attempts.popleft()

    from flask import current_app
    is_testing = current_app.config.get("TESTING", False) if current_app else False
    if not is_testing and len(_recent_attempts) >= MAX_LOCAL_ATTEMPTS:
        return jsonify({
            "error": "TOO_MANY_ATTEMPTS",
            "message": "Too many attempts entered. Please wait a moment before trying again."
        }), 429

    data = request.get_json(silent=True) or {}
    otp = str(data.get("otp", "")).strip()

    # OTP validation: exactly 6 digits
    if not otp or not re.match(r"^\d{6}$", otp):
        _recent_attempts.append(now)
        return jsonify({
            "error": "INVALID_OTP",
            "message": "Invalid OTP. Please check the OTP and try again."
        }), 400

    # Verify physical printer is online
    printer_state, _ = printer_monitor.get_printer_status()
    if printer_state == "ERROR":
        return jsonify({
            "error": "PRINTER_OFFLINE",
            "message": "Printer is currently offline or in an error state. Please notify station attendant."
        }), 503

    try:
        # Submit to central FastAPI backend
        release_data = backend_client.release_job(otp)
    except OTPReleaseException as e:
        _recent_attempts.append(now)
        err_code = e.error_code
        err_msg = e.message
        if err_code == "INVALID_OTP":
            err_msg = "Invalid OTP. Please check the OTP and try again."
        elif err_code == "OTP_EXPIRED":
            err_msg = "OTP Expired. Please generate/request a new OTP."
        elif err_code in ("ORDER_ALREADY_COMPLETED", "ALREADY_PRINTED"):
            err_msg = "This order has already been printed."
        elif err_code == "TOO_MANY_ATTEMPTS":
            err_msg = "Maximum OTP attempts exceeded. Please generate/request a new OTP."
        return jsonify({"error": err_code, "message": err_msg}), e.status_code
    except BackendCommunicationException as e:
        return jsonify({"error": e.error_code, "message": e.message}), e.status_code
    except Exception as e:
        agent_logger.error(f"Unexpected local release error: {e}")
        return jsonify({
            "error": "RELEASE_FAILED",
            "message": "An unexpected error occurred while processing OTP."
        }), 500

    if not release_data:
        _recent_attempts.append(now)
        return jsonify({
            "error": "RELEASE_FAILED",
            "message": "OTP verification failed or no queued job."
        }), 400

    # Start printing immediately if not already active or completed
    job_id = release_data.get("jobId") or release_data.get("job_id")
    order_id = release_data.get("orderId") or release_data.get("order_id")
    if job_id and not print_service.is_job_active_or_done(job_id):
        job_poller.processing_jobs.add(job_id)
        import threading
        threading.Thread(
            target=job_poller._execute_job_safely,
            args=(release_data,),
            daemon=True
        ).start()

    return jsonify({
        "status": "RELEASED",
        "message": "OTP Verified. Printing Started. Please collect your document.",
        "jobId": job_id,
        "orderId": order_id
    }), 200

@local_bp.route("/print-job", methods=["POST", "OPTIONS"])
def direct_print_job():
    if request.method == "OPTIONS":
        return "", 200
    data = request.get_json(silent=True) or {}
    job_id = data.get("jobId") or data.get("job_id")
    if not job_id:
        return jsonify({"error": "MISSING_JOB_ID"}), 400

    if not print_service.is_job_active_or_done(job_id):
        job_poller.processing_jobs.add(job_id)
        import threading
        threading.Thread(
            target=job_poller._execute_job_safely,
            args=(data,),
            daemon=True
        ).start()
        return jsonify({"status": "PRINTING", "job_id": job_id}), 200
    return jsonify({"status": "ALREADY_ACTIVE", "job_id": job_id}), 200
