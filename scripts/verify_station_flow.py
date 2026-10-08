"""Run isolated backend/agent HTTP processes and an explicit simulated CUPS job.

Uses temporary SQLite databases/storage and loopback ports. No real payment,
printer, current database, or running station is touched.
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time

import requests

ROOT = Path(__file__).resolve().parents[1]


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def wait_for(predicate, description, timeout=45):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if predicate():
                return
        except requests.RequestException:
            pass
        time.sleep(0.25)
    raise RuntimeError(f"Timed out: {description}")


BACKEND_BOOTSTRAP = r'''
import hashlib, json, os
from pathlib import Path
from datetime import datetime, timezone
from pypdf import PdfWriter
from app.db.base import Base
from app.config.database import engine, SessionLocal
from app.config.security import hash_token
from app.db.models.document import Document
from app.db.models.order import Order, OrderStatus
from app.db.models.print_job import PrintJob, PrintJobStatus
from app.db.models.payment import Payment, PaymentStatus
from app.db.models.printer import Printer
from app.db.models.print_server import PrintServer, PrintServerStatus
from app.services.otp_service import otp_service
Base.metadata.create_all(engine)
storage = Path(os.environ["STORAGE_ROOT"])
(storage / "documents").mkdir(parents=True, exist_ok=True)
file = storage / "documents" / "http-flow.pdf"
writer = PdfWriter()
writer.add_blank_page(width=595, height=842)
writer.write(str(file))
with SessionLocal() as db:
    db.add(PrintServer(id="HTTP-STATION", name="HTTP test station", location="Simulation",
        device_token_hash=hash_token("http-test-device-token"), status=PrintServerStatus.ONLINE,
        last_heartbeat=datetime.now(timezone.utc)))
    db.add(Document(id="HTTP-DOC", session_token="sess_http_verification", original_filename="http-flow.pdf",
        stored_filename="http-flow.pdf", storage_key="documents/http-flow.pdf", mime_type="application/pdf",
        file_size=file.stat().st_size, sha256=hashlib.sha256(file.read_bytes()).hexdigest(), page_count=1))
    db.commit()
    db.add(Printer(id="HTTP-PRINTER", server_id="HTTP-STATION", cups_printer_name="HTTP_Test_Queue",
        display_name="HTTP test printer", is_enabled=True, is_active=True))
    db.add(Order(id="HTTP-ORDER", document_id="HTTP-DOC", print_server_id="HTTP-STATION",
        print_settings={"copies": 1, "session_token": "sess_http_verification"}, total_pages=1, copies=1,
        amount=2, currency="INR", status=OrderStatus.WAITING_FOR_OTP))
    db.commit()
    db.add(PrintJob(id="HTTP-JOB", order_id="HTTP-ORDER", server_id="HTTP-STATION", status=PrintJobStatus.QUEUED))
    db.add(Payment(id="HTTP-PAYMENT", order_id="HTTP-ORDER", razorpay_order_id="order_HttpFixture",
        razorpay_payment_id="pay_HttpFixture", amount=2, currency="INR", status=PaymentStatus.CAPTURED))
    code = otp_service.generate_and_store_otp(db, "HTTP-ORDER")
    db.commit()
    Path(os.environ["FIXTURE_PATH"]).write_text(json.dumps({"otp": code}))
import uvicorn
uvicorn.run("app.main:app", host="127.0.0.1", port=int(os.environ["HTTP_TEST_PORT"]), log_level="warning")
'''

AGENT_BOOTSTRAP = r'''
from app.main import run_agent
run_agent()
'''

FRONTEND_BOOTSTRAP = r'''
import sys
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]) / "scripts"))
from serve_frontend import Handler
import os
ThreadingHTTPServer(("127.0.0.1", int(os.environ["FRONTEND_TEST_PORT"])), partial(Handler, directory=sys.argv[1])).serve_forever()
'''


def main():
    processes = []
    with tempfile.TemporaryDirectory(prefix="achuppori-http-check-") as temp:
        workspace = Path(temp)
        backend_port, agent_port, frontend_port = free_port(), free_port(), free_port()
        backend_url, agent_url = f"http://127.0.0.1:{backend_port}", f"http://127.0.0.1:{agent_port}"
        common = {**os.environ, "ENVIRONMENT": "development", "JWT_SECRET_KEY": "isolated-http-test-secret-32-characters",
                  "ADMIN_PASSWORD": "", "RAZORPAY_KEY_ID": "", "RAZORPAY_KEY_SECRET": ""}
        backend_env = {**common, "PYTHONPATH": str(ROOT / "backend"),
                       "DATABASE_URL": "sqlite:///" + (workspace / "backend.sqlite3").as_posix(),
                       "STORAGE_ROOT": str(workspace / "backend-storage"),
                       "FIXTURE_PATH": str(workspace / "fixture.json"), "HTTP_TEST_PORT": str(backend_port)}
        agent_env = {**common, "PYTHONPATH": str(ROOT / "print-agent"), "AGENT_ID": "HTTP-STATION",
                     "AGENT_TOKEN": "http-test-device-token", "BACKEND_URL": backend_url + "/api",
                     "KIOSK_WEB_URL": backend_url, "MOCK_CUPS": "true", "PRINTER_NAME": "HTTP_Test_Queue",
                     "STORAGE_ROOT": str(workspace / "agent-storage"), "LOG_DIR": str(workspace / "agent-logs"),
                     "POLL_INTERVAL_SECONDS": "1", "HEARTBEAT_INTERVAL_SECONDS": "1", "PORT": str(agent_port)}
        frontend_env = {**common, "BACKEND_PROXY_PORT": str(backend_port), "FRONTEND_TEST_PORT": str(frontend_port)}
        flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
        with (workspace / "processes.log").open("w", encoding="utf-8") as log:
            try:
                for bootstrap, environment in ((BACKEND_BOOTSTRAP, backend_env), (AGENT_BOOTSTRAP, agent_env)):
                    processes.append(subprocess.Popen([sys.executable, "-c", bootstrap], env=environment,
                        cwd=workspace, stdout=log, stderr=log, creationflags=flags))
                processes.append(subprocess.Popen([sys.executable, "-c", FRONTEND_BOOTSTRAP, str(ROOT)], env=frontend_env,
                    cwd=workspace, stdout=log, stderr=log, creationflags=flags))
                wait_for(lambda: requests.get(backend_url + "/health", timeout=2).status_code == 200, "backend startup")
                wait_for(lambda: requests.get(agent_url + "/health", timeout=2).status_code == 200, "agent startup")
                code = json.loads((workspace / "fixture.json").read_text())["otp"]
                released = requests.post(agent_url + "/local/release", json={"otp": code}, timeout=15)
                assert released.status_code == 200, released.text
                customer_headers = {"X-Customer-Session": "sess_http_verification"}
                website = f"http://127.0.0.1:{frontend_port}"
                wait_for(lambda: requests.get(website + "/health", timeout=2).status_code == 200, "frontend API proxy")
                assert requests.get(website + "/api/orders/HTTP-ORDER", headers=customer_headers, timeout=3).status_code == 200
                assert requests.get(website + "/api/orders/HTTP-ORDER", timeout=3).status_code in (401, 403)
                def completed():
                    response = requests.get(backend_url + "/api/orders/HTTP-ORDER", headers=customer_headers, timeout=3)
                    return response.status_code == 200 and response.json()["status"] == "COMPLETED"
                wait_for(completed, "CUPS simulation and backend completion")
                assert requests.get(agent_url + "/local/job-status/HTTP-JOB", timeout=3).json()["status"] == "COMPLETED"
                repeated = requests.post(agent_url + "/local/release", json={"otp": code}, timeout=15)
                assert repeated.status_code == 400 and repeated.json()["error"] == "ALREADY_PRINTED"
                assert not (workspace / "agent-storage" / "documents" / "http-flow.pdf").exists()
                print("PASS: backend/agent HTTP, frontend API proxy/customer isolation, OTP release, download, exclusive claim, simulated CUPS completion, status propagation, duplicate rejection, spool cleanup.")
            except Exception:
                log.flush()
                print((workspace / "processes.log").read_text(encoding="utf-8"), file=sys.stderr)
                raise
            finally:
                from process_utils import stop_process
                for process in processes:
                    stop_process(process)


if __name__ == "__main__":
    main()
