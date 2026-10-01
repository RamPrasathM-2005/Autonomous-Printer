#!/usr/bin/env bash
# ==============================================================================
# Autonomous Self-Service Printing Platform - Master Services Launcher
# Runs the entire project across all ports & pages in a single command:
#   * Port 8000: FastAPI Central Backend & REST API
#   * Port 5001: Flask Hardware Print Agent & Physical Station Kiosk Terminal
#   * Port 3000: Flutter Web Customer Interface
#   * Port 3100: React Web Customer Interface
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# If --gui requested, launch visual terminal tabs on screen
if [ "$1" = "--gui" ]; then
    exec "$SCRIPT_DIR/start_gui_terminals.sh"
fi

echo ""
echo -e "\033[1;36m====================================================================\033[0m"
echo -e "\033[1;36m       AUTONOMOUS SELF-SERVICE PRINTING PLATFORM (ALL SERVICES)     \033[0m"
echo -e "\033[1;36m====================================================================\033[0m"
echo ""

# 1. Kill any existing instances on all project ports
echo -e "\033[1;33m[*] Clearing any stale processes on ports 8000, 5001, 5000, 3000, 3100...\033[0m"
fuser -k -9 8000/tcp 2>/dev/null || true
fuser -k -9 5001/tcp 2>/dev/null || true
fuser -k -9 5000/tcp 2>/dev/null || true
fuser -k -9 3000/tcp 2>/dev/null || true
fuser -k -9 3100/tcp 2>/dev/null || true
pkill -9 -f "run -d web-server" 2>/dev/null || true
pkill -9 -f "frontend_server_aot" 2>/dev/null || true
sleep 1

# 2. Determine Python executable
if [ -f "$SCRIPT_DIR/venv/bin/python" ]; then
    PYTHON_EXE="$SCRIPT_DIR/venv/bin/python"
    UVICORN_EXE="$SCRIPT_DIR/venv/bin/uvicorn"
elif command -v python3 &> /dev/null; then
    PYTHON_EXE="python3"
    UVICORN_EXE="uvicorn"
else
    echo -e "\033[1;31mError: Python 3 not found!\033[0m"
    exit 1
fi

# 3. Determine Flutter executable
if [ -f "$HOME/flutter/bin/flutter" ]; then
    export PATH="$HOME/flutter/bin:$PATH"
fi

# Ensure storage directory exists
mkdir -p "$SCRIPT_DIR/storage"
mkdir -p "$SCRIPT_DIR/storage/documents/public"
mkdir -p "$SCRIPT_DIR/storage/printed_outputs"

# Process tracking for clean termination
PIDS=()

cleanup() {
    echo ""
    echo -e "\033[1;33m[!] Stopping all Autonomous Print services...\033[0m"
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    fuser -k 8000/tcp 2>/dev/null || true
    fuser -k 5001/tcp 2>/dev/null || true
    fuser -k 3000/tcp 2>/dev/null || true
    fuser -k 3100/tcp 2>/dev/null || true
    pkill -f "cloudflared.*tunnel" 2>/dev/null || true
    pkill -f "flutter_hot_watcher" 2>/dev/null || true
    rm -f /tmp/flutter_web.pid 2>/dev/null || true
    rm -f "$SCRIPT_DIR/storage/tunnel_url.txt" 2>/dev/null || true
    rm -f "$SCRIPT_DIR/print-agent/storage/tunnel_url.txt" 2>/dev/null || true
    wait 2>/dev/null || true
    echo -e "\033[1;32m[✓] All services cleanly stopped.\033[0m"
}
trap cleanup SIGINT SIGTERM

# 4. Launch FastAPI Backend (Port 8000)
echo -e "\033[1;32m[1/4] Starting FastAPI Backend on http://0.0.0.0:8000 ...\033[0m"
(cd "$SCRIPT_DIR/backend" && "$UVICORN_EXE" app.main:app --host 0.0.0.0 --port 8000 --reload) &
PIDS+=($!)
sleep 2

# Auto-configure ADB reverse proxy for connected Android devices (for mobile app USB connection)
if command -v adb &> /dev/null; then
    if adb get-state 2>/dev/null | grep -q "device"; then
        echo -e "\033[1;32m[*] Configuring USB reverse proxy (adb reverse) for Android device...\033[0m"
        adb reverse tcp:8000 tcp:8000 2>/dev/null || true
        adb reverse tcp:5001 tcp:5001 2>/dev/null || true
    fi
fi

# 5. Launch Flask Print Agent & Kiosk Terminal (Port 5001)
echo -e "\033[1;34m[2/4] Starting Flask Print Agent & Kiosk Terminal on http://127.0.0.1:5001 ...\033[0m"
(cd "$SCRIPT_DIR/print-agent" && "$PYTHON_EXE" app/main.py) &
PIDS+=($!)
sleep 2

# 6. Launch Flutter Web Frontend (Port 3000)
HOT_RELOAD=false
FORCE_BUILD=false
BUILD_APK=false
WANT_TUNNEL=true

for arg in "$@"; do
    case "$arg" in
        --hot|--hot-reload|--hotreload|--dev|-d) HOT_RELOAD=true ;;
        --build|-build|-Build|-b) FORCE_BUILD=true ;;
        --build-apk|--apk) BUILD_APK=true ;;
        --no-tunnel|--notunnel|-nt) WANT_TUNNEL=false ;;
        --prod|--static) HOT_RELOAD=false ;;
    esac
done

if [ "$BUILD_APK" = true ]; then
    "$SCRIPT_DIR/scripts/build_apk.sh"
fi

if [ "$HOT_RELOAD" = true ]; then
    echo -e "\033[1;36m[3/4] Starting Flutter Web in LIVE HOT-RELOAD mode on http://0.0.0.0:3000 ...\033[0m"
    echo -e "\033[2m      (Auto-watches frontend/lib/*.dart; press 'r' for manual reload, 'R' for restart)\033[0m"
    rm -f /tmp/flutter_web.pid
    (cd "$SCRIPT_DIR/frontend" && flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0 --pid-file /tmp/flutter_web.pid) &
    PIDS+=($!)
    # Start auto-watcher daemon for instant automatic hot reloads on save
    "$PYTHON_EXE" "$SCRIPT_DIR/scripts/flutter_hot_watcher.py" &
    PIDS+=($!)
elif [ "$FORCE_BUILD" = true ] || [ ! -d "$SCRIPT_DIR/frontend/build/web" ]; then
    if command -v flutter &> /dev/null; then
        echo -e "\033[1;36m[*] Building Flutter Web production bundle...\033[0m"
        (cd "$SCRIPT_DIR/frontend" && flutter build web --release --no-wasm-dry-run)
    fi
    if [ -d "$SCRIPT_DIR/frontend/build/web" ]; then
        echo -e "\033[1;36m[3/4] Starting Flutter Web App on http://0.0.0.0:3000 ...\033[0m"
        (cd "$SCRIPT_DIR/frontend/build/web" && "$PYTHON_EXE" -m http.server 3000 --bind 0.0.0.0) &
        PIDS+=($!)
    fi
elif [ -d "$SCRIPT_DIR/frontend/build/web" ]; then
    echo -e "\033[1;36m[3/4] Starting Flutter Web App on http://0.0.0.0:3000 (Pass --hot for Live Reload) ...\033[0m"
    (cd "$SCRIPT_DIR/frontend/build/web" && "$PYTHON_EXE" -m http.server 3000 --bind 0.0.0.0) &
    PIDS+=($!)
elif command -v flutter &> /dev/null; then
    echo -e "\033[1;36m[3/4] Starting Flutter Web in Live Hot-Reload mode on http://0.0.0.0:3000 ...\033[0m"
    rm -f /tmp/flutter_web.pid
    (cd "$SCRIPT_DIR/frontend" && flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0 --pid-file /tmp/flutter_web.pid) &
    PIDS+=($!)
    "$PYTHON_EXE" "$SCRIPT_DIR/scripts/flutter_hot_watcher.py" &
    PIDS+=($!)
else
    echo -e "\033[1;33m[3/4] Flutter build not found. Skipping Port 3000.\033[0m"
fi
sleep 1

# Cloudflare Quick Tunnel (Runs always by default; pass --no-tunnel to disable)
if [ "$WANT_TUNNEL" = true ]; then
    echo -e "\033[1;33m[4/4] Starting Cloudflare Quick Tunnel...\033[0m"
    "$SCRIPT_DIR/start_tunnel.sh" &
    PIDS+=($!)
    sleep 3
fi

echo ""
echo -e "\033[1;32m====================================================================\033[0m"
echo -e "\033[1;32m   ✓ ALL PROJECT SERVICES ARE ACTIVE AND RUNNING!                  \033[0m"
echo -e "\033[1;32m====================================================================\033[0m"
if [ "$HOT_RELOAD" = true ]; then
    echo -e "   \033[1m1. Customer Flutter Web App:\033[0m   \033[1;36mhttp://127.0.0.1:3000\033[0m \033[1;32m[🔥 LIVE HOT-RELOAD ACTIVE]\033[0m"
else
    echo -e "   \033[1m1. Customer Flutter Web App:\033[0m   \033[1;36mhttp://127.0.0.1:3000\033[0m \033[2m(Pass --hot for live reload)\033[0m"
fi
echo -e "   \033[1m2. Physical Kiosk Screen:\033[0m      \033[1;34mhttp://127.0.0.1:5001/kiosk\033[0m"
echo -e "   \033[1m3. FastAPI Backend & Docs:\033[0m     \033[1;32mhttp://127.0.0.1:8000/docs\033[0m"
if [ -f "$SCRIPT_DIR/storage/tunnel_url.txt" ]; then
    TUNNEL_DISPLAY=$(cat "$SCRIPT_DIR/storage/tunnel_url.txt" 2>/dev/null || true)
    echo -e "   \033[1m4. Cloudflare Public URL:\033[0m      \033[1;33m$TUNNEL_DISPLAY\033[0m"
fi
echo -e "\033[1;32m====================================================================\033[0m"
echo -e "   \033[2mPress Ctrl+C at any time to cleanly stop all running services.\033[0m"
echo ""

# Keep running and wait on all child processes
wait
