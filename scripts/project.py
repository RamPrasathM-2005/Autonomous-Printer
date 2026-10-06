"""Portable setup, cached web builds and supervised local services."""
import argparse
import hashlib
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
    current = fingerprint()
    if not force and STAMP.exists() and STAMP.read_text() == current and (STAMP.parent / "main.dart.js").exists():
        print("Web build is current.", flush=True)
        return
    run([flutter(), "pub", "get", "--enforce-lockfile"], FRONTEND)
    run([flutter(), "build", "web", "--release", "--no-pub", "--no-web-resources-cdn", "--no-wasm-dry-run"], FRONTEND)
    STAMP.write_text(fingerprint())


def setup():
    if sys.version_info < (3, 12):
        raise RuntimeError("Python 3.12 or newer is required.")
    if not PYTHON.exists():
        run([sys.executable, "-m", "venv", ROOT / ".venv"])
    run([PYTHON, "-m", "pip", "install", "-r", ROOT / "requirements.lock"])
    # Never overwrite a configured installation.
    created = []
    device_token = secrets.token_urlsafe(32)
    for folder in ("backend", "print-agent", "frontend"):
        target = ROOT / folder / ".env"
        if not target.exists():
            example = target.parent / ".env.example"
            if example.exists():
                text = example.read_text()
                if folder == "backend":
                    text = text.replace("CHANGE_ME_SUPER_SECRET_KEY_AT_LEAST_32_CHARS", secrets.token_urlsafe(48))
                    text += f"\nINTERNAL_AGENT_TOKEN={device_token}\n"
                if folder == "print-agent":
                    text = text.replace("/var/lib/printplatform/storage", "./storage")
                    text = text.replace("MOCK_CUPS=false", "MOCK_CUPS=true")
                    text = text.replace("CHANGE_ME_AGENT_DEVICE_TOKEN", device_token)
                target.write_text(text)
                created.append(folder)
                print(f"Created {folder}/.env for local development.")
    if len(created) == 2:
        run([PYTHON, ROOT / "scripts/init_local_station.py"], ROOT / "backend")
    run([flutter(), "pub", "get", "--enforce-lockfile"], FRONTEND)
    print("Setup complete. New installations use SQLite and simulated printing. Configure Razorpay test keys in backend/.env for checkout.")


def sync_dependencies():
    lock_file = ROOT / "requirements.lock"
    backend_req = ROOT / "backend" / "requirements.txt"
    stamp_file = RUNTIME / ".requirements-fingerprint"
    parts = []
    for path in (lock_file, backend_req):
        if path.exists():
            parts.append(hashlib.sha256(path.read_bytes()).hexdigest().upper())
    current_hash = "".join(parts)
    if stamp_file.exists() and stamp_file.read_text().strip().upper() == current_hash:
        return
    print("Synchronizing Python dependencies...", flush=True)
    cmd = [PYTHON, "-m", "pip", "install"]
    if lock_file.exists():
        cmd.extend(["-r", lock_file])
    if backend_req.exists():
        cmd.extend(["-r", backend_req])
    cmd.append("--quiet")
    run(cmd)
    RUNTIME.mkdir(exist_ok=True)
    stamp_file.write_text(current_hash)


def serve(hot=False, force=False):
    if not PYTHON.exists():
        raise RuntimeError("Run python scripts/project.py setup first.")
    sync_dependencies()
    from dotenv import dotenv_values
    agent_port = int(dotenv_values(ROOT / "print-agent/.env").get("PORT") or 5001)
    for port in (8000, agent_port, 3000):
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
        start("agent", ROOT / "print-agent", ["-m", "app.main"], f"http://127.0.0.1:{agent_port}/health")
        args = ["scripts/flutter_hot_watcher.py", "--serve", "--port", "3000"] if hot else ["scripts/serve_frontend.py"]
        start("frontend", ROOT, args, "http://127.0.0.1:3000/", 180 if hot else 45)
        print(f"App: http://127.0.0.1:3000/ | Keypad: http://127.0.0.1:{agent_port}/kiosk", flush=True)
        print("Logs: .runtime/ | Ctrl+C to stop", flush=True)
        while True:
            if any(child.poll() is not None for child in children):
                raise RuntimeError("A service exited. See .runtime logs.")
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        for child in reversed(children):
            if child.poll() is None:
                child.terminate()
        for child in children:
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
        for log in logs:
            log.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "build", "run"])
    parser.add_argument("--build", action="store_true", help="Force rebuilding the web bundle")
    parser.add_argument("--hot", action="store_true")
    args = parser.parse_args()
    if args.command == "setup":
        setup()
    elif args.command == "build":
        build(args.build)
    else:
        if PYTHON.exists() and Path(sys.executable).resolve() != PYTHON.resolve():
            os.execv(str(PYTHON), [f'"{PYTHON}"', f'"{Path(__file__).resolve()}"', *sys.argv[1:]])
        serve(args.hot, args.build)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        sys.exit(1)
