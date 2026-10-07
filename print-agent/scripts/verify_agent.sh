#!/usr/bin/env bash
# ==============================================================================
# Autonomous Printer - Agent & Station Diagnostics Verifier
# Run anytime to verify runtime health, CUPS, memory, SSD, and backend links.
# ==============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================================="
echo " Achuppori Print Agent Diagnostics (Raspberry Pi 3 Model B)"
echo "=================================================================="

# 1. System Resources
echo -e "\n[1] Hardware & Resource Utilization:"
echo " - Free Memory (RAM):"
free -h | awk 'NR==2{printf "   Used: %s / Total: %s (Available: %s)\n", $3, $2, $7}'
echo " - SSD Storage Usage:"
df -h "$AGENT_DIR" | awk 'NR==2{printf "   Used: %s / Total: %s (Free: %s, Use%%: %s)\n", $3, $2, $4, $5}'

# 2. Print Agent Daemon Status
echo -e "\n[2] Print Agent Service Status:"
if systemctl is-active print-agent.service &>/dev/null; then
    echo " - Systemd Service: ACTIVE (running)"
else
    echo " - Systemd Service: NOT RUNNING (run 'sudo systemctl start print-agent.service')"
fi

# 3. Local Health Endpoint
echo -e "\n[3] Local HTTP API Health:"
HEALTH_RESP=$(curl -s --max-time 3 http://127.0.0.1:5001/health 2>/dev/null || echo "FAILED")
if echo "$HEALTH_RESP" | grep -q "healthy"; then
    echo " - Local /health: OK (HTTP 200)"
    echo "   $HEALTH_RESP"
else
    echo " - Local /health: UNREACHABLE ($HEALTH_RESP)"
fi

# 4. CUPS Printing Subsystem
echo -e "\n[4] Local CUPS Status:"
if systemctl is-active cups &>/dev/null; then
    echo " - CUPS Daemon: ACTIVE"
    if command -v lpstat &>/dev/null; then
        echo " - Connected Printers:"
        lpstat -p -d 2>/dev/null || echo "   No CUPS printers configured yet."
    fi
else
    echo " - CUPS Daemon: INACTIVE (run 'sudo systemctl start cups')"
fi

# 5. Backend Server Connectivity
echo -e "\n[5] Central Backend Connectivity:"
if [ -f "$AGENT_DIR/.env" ]; then
    BACKEND_URL=$(grep -E "^BACKEND_URL=" "$AGENT_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    AGENT_TOKEN=$(grep -E "^AGENT_TOKEN=" "$AGENT_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [ -n "$BACKEND_URL" ]; then
        echo " - Backend Endpoint: $BACKEND_URL"
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
            -H "Authorization: Bearer $AGENT_TOKEN" \
            "$BACKEND_URL/agent/jobs" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ]; then
            echo " - Backend API: CONNECTED (HTTP 200, Authenticated)"
        elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
            echo " - Backend API: REACHABLE but AUTHENTICATION REJECTED (HTTP $HTTP_CODE - check AGENT_TOKEN)"
        else
            echo " - Backend API: FAILED (HTTP Code: $HTTP_CODE)"
        fi
    fi
else
    echo " - Warning: $AGENT_DIR/.env file not found."
fi

echo -e "\n=================================================================="
