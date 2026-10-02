#!/usr/bin/env python3
"""Cross-platform Flutter Hot Reload supervisor and watcher.

Supports:
1. Supervisor Mode (--serve): Launches 'flutter run -d web-server' with a direct
   stdin pipe, watches frontend/lib/**/*.dart, and streams 'r\\n' to trigger
   instant hot reloads on save across Windows, Linux, and macOS.
2. Standalone Watcher Mode: Watches frontend/lib and signals an existing Flutter
   process via PID file (using SIGUSR1 on POSIX, or hot_reload_trigger file on Windows).
"""
import argparse
import os
import shutil
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent.parent
FRONTEND_DIR = SCRIPT_DIR / "frontend"
LIB_DIR = FRONTEND_DIR / "lib"
RUNTIME_DIR = SCRIPT_DIR / ".runtime"
TRIGGER_FILE = RUNTIME_DIR / "hot_reload_trigger"

DEFAULT_PID_FILE = (
    RUNTIME_DIR / "flutter_web.pid" if os.name == "nt" else Path("/tmp/flutter_web.pid")
)


def find_flutter() -> str:
    """Find the Flutter executable on the system path or standard install locations."""
    if os.name == "nt":
        for name in ("flutter.bat", "flutter.cmd", "flutter.exe"):
            found = shutil.which(name)
            if found:
                return found
        # Common fallback paths on Windows
        for candidate in (
            Path(r"D:\flutter\bin\flutter.bat"),
            Path(r"C:\flutter\bin\flutter.bat"),
            Path(os.environ.get("USERPROFILE", r"C:\Users\Default")) / "flutter" / "bin" / "flutter.bat",
        ):
            if candidate.exists():
                return str(candidate)
    return shutil.which("flutter") or "flutter"


def get_lib_mtimes(watch_dir: Path) -> dict:
    """Collect modification times for all Dart source files under the target directory."""
    mtimes = {}
    if not watch_dir.exists():
        return mtimes
    for p in watch_dir.rglob("*.dart"):
        try:
            mtimes[p] = p.stat().st_mtime
        except OSError:
            pass
    return mtimes


def run_supervisor(port: int, host: str, watch_dir: Path, pid_file: Path) -> int:
    """Run Flutter Web dev-server as a child process and pipe hot reload commands on file save."""
    flutter_bin = find_flutter()
    print(f"[HotWatcher] Using Flutter executable: {flutter_bin}", flush=True)
    print(f"[HotWatcher] Starting Flutter Web server on http://{host}:{port} ...", flush=True)

    cmd = [
        flutter_bin,
        "run",
        "-d",
        "web-server",
        f"--web-port={port}",
        f"--web-hostname={host}",
        "--no-pub",
    ]

    # Ensure runtime dir exists
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

    # Launch Flutter with piped stdin and direct stdout/stderr passthrough
    proc = subprocess.Popen(
        cmd,
        cwd=str(FRONTEND_DIR),
        stdin=subprocess.PIPE,
        stdout=sys.stdout,
        stderr=sys.stderr,
        bufsize=0,
    )

    # Save PID
    try:
        pid_file.write_text(str(proc.pid), encoding="utf-8")
    except Exception as e:
        print(f"[HotWatcher] Note: Could not write pid file: {e}", flush=True)

    stop_event = threading.Event()

    def handle_exit(signum, frame):
        stop_event.set()
        if proc.poll() is None:
            try:
                if proc.stdin and not proc.stdin.closed:
                    proc.stdin.write(b"q\n")
                    proc.stdin.flush()
                proc.wait(timeout=4)
            except Exception:
                proc.kill()
        sys.exit(0)

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            signal.signal(sig, handle_exit)
        except (ValueError, AttributeError):
            pass

    def file_watcher_loop():
        last_mtimes = get_lib_mtimes(watch_dir)
        last_trigger_mtime = 0.0
        if TRIGGER_FILE.exists():
            try:
                last_trigger_mtime = TRIGGER_FILE.stat().st_mtime
            except OSError:
                pass

        print(f"[HotWatcher] Auto-watching {watch_dir} for Dart changes...", flush=True)

        while not stop_event.is_set():
            if proc.poll() is not None:
                stop_event.set()
                break

            time.sleep(0.5)
            changed = False
            reason = ""

            # Check trigger file
            if TRIGGER_FILE.exists():
                try:
                    cur_trig = TRIGGER_FILE.stat().st_mtime
                    if cur_trig > last_trigger_mtime:
                        last_trigger_mtime = cur_trig
                        changed = True
                        reason = "manual reload trigger"
                except OSError:
                    pass

            # Check Dart files
            if not changed:
                cur_mtimes = get_lib_mtimes(watch_dir)
                for p, mtime in cur_mtimes.items():
                    if p not in last_mtimes or mtime > last_mtimes[p]:
                        changed = True
                        reason = p.name
                        break
                if not changed and len(cur_mtimes) != len(last_mtimes):
                    changed = True
                    reason = "file addition/removal in lib/"
                last_mtimes = cur_mtimes

            if changed and proc.poll() is None and proc.stdin and not proc.stdin.closed:
                try:
                    proc.stdin.write(b"r\n")
                    proc.stdin.flush()
                    print(f"\n[HotWatcher] 🔥 Triggered Flutter Hot-Reload ({reason})", flush=True)
                except Exception as ex:
                    print(f"[HotWatcher] Could not trigger hot reload: {ex}", flush=True)
                time.sleep(0.5)  # debounce

    watcher_thread = threading.Thread(target=file_watcher_loop, daemon=True)
    watcher_thread.start()

    try:
        ret = proc.wait()
    except KeyboardInterrupt:
        handle_exit(None, None)
        ret = 0
    finally:
        stop_event.set()
        if pid_file.exists():
            try:
                pid_file.unlink()
            except OSError:
                pass

    return ret


def run_standalone_watcher(watch_dir: Path, pid_file: Path):
    """Standalone watcher mode for environments where Flutter was started externally."""
    print(f"[HotWatcher] Watching {watch_dir} for Dart changes...", flush=True)
    last_mtimes = get_lib_mtimes(watch_dir)

    while True:
        try:
            time.sleep(0.5)
            cur_mtimes = get_lib_mtimes(watch_dir)
            changed = False
            reason = ""

            for p, mtime in cur_mtimes.items():
                if p not in last_mtimes or mtime > last_mtimes[p]:
                    changed = True
                    reason = p.name
                    break
            if not changed and len(cur_mtimes) != len(last_mtimes):
                changed = True
                reason = "file addition/removal"

            if changed:
                last_mtimes = cur_mtimes
                # Check for PID file
                resolved_pid_file = pid_file if pid_file.exists() else DEFAULT_PID_FILE
                if resolved_pid_file.exists():
                    try:
                        pid = int(resolved_pid_file.read_text(encoding="utf-8").strip())
                        # Check POSIX signals
                        if hasattr(signal, "SIGUSR1"):
                            os.kill(pid, signal.SIGUSR1)
                            print(f"[HotWatcher] 🔥 Triggered Flutter Hot-Reload (PID {pid}, {reason})", flush=True)
                        else:
                            # On Windows, touch trigger file if supervisor is active
                            TRIGGER_FILE.parent.mkdir(parents=True, exist_ok=True)
                            TRIGGER_FILE.write_text(str(time.time()), encoding="utf-8")
                            print(f"[HotWatcher] 🔥 Touched reload trigger for {reason}", flush=True)
                    except ProcessLookupError:
                        pass
                    except Exception as e:
                        print(f"[HotWatcher] Could not notify PID: {e}", flush=True)
                else:
                    # Touch trigger file as fallback
                    TRIGGER_FILE.parent.mkdir(parents=True, exist_ok=True)
                    TRIGGER_FILE.write_text(str(time.time()), encoding="utf-8")

                time.sleep(0.5)  # debounce
        except KeyboardInterrupt:
            break
        except Exception:
            time.sleep(1)


def main():
    parser = argparse.ArgumentParser(description="Flutter Hot-Reload supervisor and watcher")
    parser.add_argument("--serve", action="store_true", help="Launch and supervise flutter run with hot reload")
    parser.add_argument("--port", type=int, default=3000, help="Web port (default: 3000)")
    parser.add_argument(
        "--host",
        type=str,
        default="127.0.0.1" if os.name == "nt" else "0.0.0.0",
        help="Web hostname/IP to bind",
    )
    parser.add_argument("--pid-file", type=Path, default=DEFAULT_PID_FILE, help="Path to flutter pid file")
    parser.add_argument("--watch-dir", type=Path, default=LIB_DIR, help="Directory to watch for changes")

    args = parser.parse_args()

    if args.serve:
        sys.exit(run_supervisor(args.port, args.host, args.watch_dir, args.pid_file))
    else:
        run_standalone_watcher(args.watch_dir, args.pid_file)


if __name__ == "__main__":
    main()
