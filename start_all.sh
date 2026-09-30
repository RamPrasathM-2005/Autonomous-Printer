#!/usr/bin/env bash
# ==============================================================================
# Autonomous Self-Service Printing Platform - Linux Services Launcher
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# If --gui requested, launch visual terminal tabs on screen
if [ "$1" = "--gui" ]; then
    exec "$SCRIPT_DIR/start_gui_terminals.sh"
fi

echo "========================================================"
echo " Starting Autonomous Print Hub Services (Linux / Ubuntu) "
echo "========================================================"

# 1. Determine Python executable
if [ -f "$SCRIPT_DIR/venv/bin/python" ]; then
    PYTHON_EXE="$SCRIPT_DIR/venv/bin/python"
    UVICORN_EXE="$SCRIPT_DIR/venv/bin/uvicorn"
elif command -v python3 &> /dev/null; then
    PYTHON_EXE="python3"
    UVICORN_EXE="uvicorn"
else
    echo "Error: Python 3 not found!"
    exit 1
fi

# 2. Determine Flutter executable
if [ -f "$HOME/flutter/bin/flutter" ]; then
    export PATH="$HOME/flutter/bin:$PATH"
fi

# Ensure storage directory exists
mkdir -p "$SCRIPT_DIR/storage"

# Process tracking for clean termination
PIDS=()

cleanup() {
    echo ""
    echo "Shutting down all services..."
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null || true
    echo "All services stopped."
}
trap cleanup SIGINT SIGTERM EXIT

# 3. Launch FastAPI Backend
echo "[1/3] Launching FastAPI Backend on http://127.0.0.1:8000 ..."
(cd "$SCRIPT_DIR/backend" && "$UVICORN_EXE" app.main:app --host 127.0.0.1 --port 8000 --reload) &
PIDS+=($!)
sleep 2

# 4. Launch Print Agent
echo "[2/3] Launching Print Agent on http://127.0.0.1:5000 ..."
(cd "$SCRIPT_DIR/print-agent" && "$PYTHON_EXE" app/main.py) &
PIDS+=($!)
sleep 2

# 5. Launch Flutter Frontend
if [ "$1" = "--dev" ] && command -v flutter &> /dev/null; then
    echo "[3/3] Launching Flutter Web in DEV / Hot-Reload mode on http://127.0.0.1:3000 ..."
    (cd "$SCRIPT_DIR/frontend" && flutter run -d web-server --web-port 3000 --web-hostname 127.0.0.1) &
    PIDS+=($!)
elif [ -d "$SCRIPT_DIR/frontend/build/web" ]; then
    echo "[3/3] Launching Optimized Flutter Web Frontend on http://127.0.0.1:3000 ..."
    (cd "$SCRIPT_DIR/frontend/build/web" && "$PYTHON_EXE" -m http.server 3000 --bind 127.0.0.1) &
    PIDS+=($!)
elif command -v flutter &> /dev/null; then
    echo "[3/3] Launching Flutter Web Frontend on http://127.0.0.1:3000 ..."
    (cd "$SCRIPT_DIR/frontend" && flutter run -d web-server --web-port 3000 --web-hostname 127.0.0.1) &
    PIDS+=($!)
else
    echo "[3/3] Flutter frontend not built yet. Kiosk UI is directly available at: http://127.0.0.1:8000/kiosk"
fi

echo ""
echo "========================================================"
echo " All services running! Press Ctrl+C to stop all."
echo "   * Backend Swagger:   http://127.0.0.1:8000/docs"
echo "   * Kiosk Terminal:    http://127.0.0.1:8000/kiosk"
echo "   * Print Agent API:   http://127.0.0.1:5000"
echo "   * Flutter Web App:   http://127.0.0.1:3000"
echo "========================================================"
echo ""

# Keep running and wait on all child processes
wait
