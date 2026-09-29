from flask import Blueprint, jsonify, request
from app.config import config
from app.services.printer_monitor import printer_monitor
from app.services.job_poller import job_poller
from app.services.backend_client import backend_client
from app.services.print_service import print_service

local_bp = Blueprint("local", __name__, url_prefix="/local")

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
    data = request.get_json(silent=True) or {}
    otp = data.get("otp", "").strip()

    if not otp:
        return jsonify({"error": "INVALID_OTP", "message": "OTP is required"}), 400

    # Submit to central FastAPI backend
    release_data = backend_client.release_job(otp)
    if not release_data:
        return jsonify({"error": "RELEASE_FAILED", "message": "OTP verification failed or no queued job."}), 400

    # Start printing immediately
    job_id = release_data.get("jobId") or release_data.get("job_id")
    if job_id:
        job_poller.processing_jobs.add(job_id)
        import threading
        threading.Thread(
            target=job_poller._execute_job_safely,
            args=(release_data,),
            daemon=True
        ).start()

    return jsonify({
        "status": "RELEASED",
        "message": "OTP verified successfully. Printing started.",
        "job": release_data
    }), 200
