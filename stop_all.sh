#!/usr/bin/env bash
# ==============================================================================
# Achuppori - Services Stopper
# Stops all running platform services, background servers, and processes:
#   * Port 8000: FastAPI Central Backend & REST API
#   * Port 5001: Flask Hardware Print Agent & Physical Station Kiosk Terminal
#   * Port 5000: Secondary print-agent port
#   * Port 3000: Flutter Web Customer Interface
#   * Port 3100: React Web Customer Interface
#   * Background Flutter runners, python daemons, and cloudflared tunnels
# ==============================================================================

echo ""
echo -e "\033[1;33m[*] Stopping all Achuppori services...\033[0m"

# 1. Kill listeners on project ports
for port in 8000 5001 5000 3000 3100; do
    if fuser ${port}/tcp >/dev/null 2>&1; then
        echo -e "  - Terminating process listening on port \033[1;31m${port}\033[0m..."
        fuser -k -9 ${port}/tcp 2>/dev/null || true
    fi
done

# 2. Terminate matching process names
pkill -9 -f "uvicorn.*app.main:app" 2>/dev/null || true
pkill -9 -f "python.*print-agent" 2>/dev/null || true
pkill -9 -f "run -d web-server" 2>/dev/null || true
pkill -9 -f "frontend_server_aot" 2>/dev/null || true
pkill -9 -f "scripts/serve_frontend.py" 2>/dev/null || true
pkill -9 -f "cloudflared.*tunnel" 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rm -f "$SCRIPT_DIR/storage/tunnel_url.txt" 2>/dev/null || true
rm -f "$SCRIPT_DIR/print-agent/storage/tunnel_url.txt" 2>/dev/null || true

sleep 1

echo -e "\033[1;32m[✓] All services cleanly stopped.\033[0m"
echo ""
