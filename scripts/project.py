"""Portable setup, cached web builds and supervised local services."""
import argparse
import hashlib
import json
import os
import secrets
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time
from urllib.request import urlopen
from scripts.process_utils import stop_process

ROOT = Path(__file__).resolve().parents[1]
FRONTEND = ROOT / "frontend"
RUNTIME = ROOT / ".runtime"
PYTHON = ROOT / ".venv" / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
STAMP = FRONTEND / "build/web/.source-fingerprint"


def flutter():
    executable = shutil.which("flutter")
    if not executable:
        raise RuntimeError("Install Flutter 3.47.5 and add its bin directory to PATH.")
    return executable


def run(args, cwd=ROOT):
    subprocess.run([str(arg) for arg in args], cwd=cwd, check=True)


def fingerprint():
    digest = hashlib.sha256()
    paths = [FRONTEND / "pubspec.yaml", FRONTEND / "pubspec.lock"]
    for directory in ("lib", "web", "assets"):
        paths.extend(p for p in (FRONTEND / directory).rglob("*") if p.is_file())
    for path in sorted(paths):
        if path.name == "active_tunnel.dart":
            continue
        digest.update(path.relative_to(FRONTEND).as_posix().encode())
        digest.update(path.read_bytes().replace(b"\r\n", b"\n"))
    digest.update(subprocess.check_output([flutter(), "--version", "--machine"]))
    return digest.hexdigest()


def build(force=False):
    def publish_config():
        from dotenv import dotenv_values
        values = dotenv_values(FRONTEND / ".env")
        (STAMP.parent / "env.json").write_text(json.dumps({"BACKEND_URL": values.get("BACKEND_URL") or ""}))

    current = fingerprint()
    if not force and STAMP.exists() and STAMP.read_text() == current and (STAMP.parent / "main.dart.js").exists():
        print("Web build is current.", flush=True)
        publish_config()
        return
    run([flutter(), "pub", "get", "--enforce-lockfile"], FRONTEND)
    run([flutter(), "build", "web", "--release", "--no-web-resources-cdn", "--no-wasm-dry-run"], FRONTEND)
    STAMP.write_text(fingerprint())
    publish_config()


def setup(with_agent=True):
    if sys.version_info < (3, 12):
        raise RuntimeError("Python 3.12 or newer is required.")
    if not PYTHON.exists():
        run([sys.executable, "-m", "venv", ROOT / ".venv"])
    run([PYTHON, "-m", "pip", "install", "-r", ROOT / "backend/requirements.txt"])
    if with_agent:
        run([PYTHON, "-m", "pip", "install", "-r", ROOT / "print-agent/requirements.txt"])
    # Never overwrite a configured installation.
    created = []
    device_token = secrets.token_urlsafe(32)
    for folder in (("backend", "print-agent", "frontend") if with_agent else ("backend", "frontend")):
        target = ROOT / folder / ".env"
        if not target.exists():
            example = target.parent / ".env.example"
            if example.exists():
                text = example.read_text()
                if folder == "backend":
                    text = text.replace("CHANGE_ME_SUPER_SECRET_KEY_AT_LEAST_32_CHARS", secrets.token_urlsafe(48))

                if folder == "print-agent":
                    text = text.replace("/var/lib/printplatform/storage", "./storage")
                    text = text.replace("MOCK_CUPS=false", "MOCK_CUPS=true")
                    text = text.replace("CHANGE_ME_AGENT_DEVICE_TOKEN", device_token)
                target.write_text(text)
                created.append(folder)
                print(f"Created {folder}/.env for local development.")
    run([flutter(), "pub", "get", "--enforce-lockfile"], FRONTEND)
    print("Setup complete. Configure backend/.env, seed the administrator, then register departments/stations/printers in admin. Local simulation requires MOCK_CUPS=true explicitly.")


def sync_dependencies(with_agent=True):
    backend_req = ROOT / "backend" / "requirements.txt"
    stamp_file = RUNTIME / ".requirements-fingerprint"
    parts = []
    agent_req = ROOT / "print-agent/requirements.txt"
    for path in ([backend_req, agent_req] if with_agent else [backend_req]):
        if path.exists():
            parts.append(hashlib.sha256(path.read_bytes()).hexdigest().upper())
    current_hash = "".join(parts)
    if stamp_file.exists() and stamp_file.read_text().strip().upper() == current_hash:
        return
    print("Synchronizing Python dependencies...", flush=True)
    cmd = [PYTHON, "-m", "pip", "install"]
    if backend_req.exists():
        cmd.extend(["-r", backend_req])
    if with_agent:
        cmd.extend(["-r", agent_req])
    cmd.append("--quiet")
    run(cmd)
    RUNTIME.mkdir(exist_ok=True)
    stamp_file.write_text(current_hash)


def serve(hot=False, force=False, with_agent=True, server=False):
    if not PYTHON.exists():
        raise RuntimeError("Run python scripts/project.py setup first.")
    sync_dependencies(with_agent)
    from dotenv import dotenv_values
    agent_values = {**dotenv_values(ROOT / "print-agent/.env"), **os.environ}
    backend_values = {**dotenv_values(ROOT / "backend/.env"), **os.environ}
    agent_port = int(agent_values.get("PORT") or 5001)
    if with_agent and agent_values.get('MOCK_CUPS', 'false').lower() in {'true', '1', 'yes'}:
        if (backend_values.get('ENVIRONMENT', '').lower() in {'production', 'prod'} or
                backend_values.get('RAZORPAY_KEY_ID', '').startswith('rzp_live_')):
            raise RuntimeError('Local simulation requires development mode and Razorpay test keys, never live payments.')
    ports_to_check = (8000, 3000) if not with_agent else (8000, agent_port, 3000)
    for port in ports_to_check:
        with socket.socket() as sock:
            if sock.connect_ex(("127.0.0.1", port)) == 0:
                raise RuntimeError(f"Port {port} is occupied. Stop its service first.")
    if hot:
        run([flutter(), "pub", "get", "--enforce-lockfile"], FRONTEND)
    else:
        build(force)
    RUNTIME.mkdir(exist_ok=True)
    children = []
    logs = []

    def stop(*_):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop)

    def start(name, cwd, args, health=None, timeout=45):
        output = (RUNTIME / f"{name}.out.log").open("w")
        logs.append(output)
        process = subprocess.Popen([str(PYTHON), "-u", *args], executable=str(PYTHON), cwd=cwd,
                                   stdout=output, stderr=subprocess.STDOUT)
        children.append(process)
        if not health:
            return
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError(f"{name} exited. See .runtime/{name}.out.log.")
            try:
                with urlopen(health, timeout=2) as response:
                    if response.status == 200:
                        return
            except (OSError, TimeoutError):
                time.sleep(0.5)
        raise RuntimeError(f"{name} is unhealthy. See .runtime/{name}.out.log.")

    try:
        start("backend", ROOT / "backend", ["-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", "8000", "--no-proxy-headers"], "http://127.0.0.1:8000/health")
        start("reconciliation", ROOT / "backend", ["-m", "app.worker"])
        if with_agent:
            start("agent", ROOT / "print-agent", ["-m", "app.main"], f"http://127.0.0.1:{agent_port}/health")
        args = ["scripts/flutter_hot_watcher.py", "--serve", "--port", "3000"] if hot else ["scripts/serve_frontend.py"]
        start("frontend", ROOT, args, "http://127.0.0.1:3000/", 180 if hot else 45)
        active_services = ["backend", "reconciliation", "frontend"]
        if with_agent:
            active_services.insert(2, "agent")
            print(f"App: http://127.0.0.1:3000/ | Keypad: http://127.0.0.1:{agent_port}/kiosk", flush=True)
        else:
            print("App: http://127.0.0.1:3000/ (Print Agent running on external Raspberry Pi)", flush=True)
        print("Logs: .runtime/ | Ctrl+C to stop", flush=True)
        while True:
            for child, name in zip(children, active_services):
                if child.poll() is not None:
                    raise RuntimeError(f"Service '{name}' exited with code {child.poll()}. See .runtime/{name}.out.log.")
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        for child in reversed(children):
            stop_process(child)
        for log in logs:
            log.close()


def main(server=False):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "build", "run"])
    parser.add_argument("--build", action="store_true", help="Force rebuilding the web bundle")
    parser.add_argument("--hot", action="store_true")
    parser.add_argument("--no-agent", action="store_true", help="Do not run local print agent (use when agent runs on external Raspberry Pi)")
    args = parser.parse_args()
    if args.command != "setup" and PYTHON.exists() and Path(sys.executable).resolve() != PYTHON.resolve():
        entry = ROOT / ("run-server.py" if server else "run-local.py")
        raise SystemExit(subprocess.call([str(PYTHON), str(entry), *sys.argv[1:]]))
    if args.command == "setup":
        setup(with_agent=not server and not args.no_agent)
    elif args.command == "build":
        build(args.build)
    else:
        serve(hot=args.hot, force=args.build, with_agent=not server and not args.no_agent, server=server)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
