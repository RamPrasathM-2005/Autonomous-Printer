#!/usr/bin/env python3
import os
import sys
import time
import signal
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent.parent
PID_FILE = Path("/tmp/flutter_web.pid")
LIB_DIR = SCRIPT_DIR / "frontend" / "lib"

def get_mtimes():
    mtimes = {}
    if not LIB_DIR.exists():
        return mtimes
    for p in LIB_DIR.rglob("*.dart"):
        try:
            mtimes[p] = p.stat().st_mtime
        except OSError:
            pass
    return mtimes

def main():
    print("[HotWatcher] Watching frontend/lib for live Flutter changes (Auto Hot-Reload active)...")
    last_mtimes = get_mtimes()
    while True:
        try:
            time.sleep(0.5)
            current_mtimes = get_mtimes()
            changed = False
            for p, mtime in current_mtimes.items():
                if p not in last_mtimes or mtime > last_mtimes[p]:
                    changed = True
                    print(f"[HotWatcher] Detected change in: {p.name}")
                    break
            if not changed and len(current_mtimes) != len(last_mtimes):
                changed = True
                print("[HotWatcher] Detected file addition/removal in lib/")

            if changed:
                last_mtimes = current_mtimes
                if PID_FILE.exists():
                    try:
                        pid = int(PID_FILE.read_text().strip())
                        os.kill(pid, signal.SIGUSR1)
                        print(f"[HotWatcher] 🔥 Triggered Flutter Hot-Reload (PID {pid})")
                    except ProcessLookupError:
                        pass
                    except Exception as e:
                        print(f"[HotWatcher] Could not signal PID: {e}")
                time.sleep(0.5) # debounce
        except KeyboardInterrupt:
            break
        except Exception:
            time.sleep(1)

if __name__ == "__main__":
    main()
