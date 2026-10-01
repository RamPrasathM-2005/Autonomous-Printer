#!/usr/bin/env bash
# ==============================================================================
# Autonomous Self-Service Printing Platform - Trigger Instant Hot Reload
# ==============================================================================
if [ -f /tmp/flutter_web.pid ]; then
    PID=$(cat /tmp/flutter_web.pid 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill -SIGUSR1 "$PID"
        echo -e "\033[1;32m[✓] Triggered live Flutter Hot-Reload (PID $PID)\033[0m"
        exit 0
    fi
fi
echo -e "\033[1;33m[!] Flutter web process not active with hot reload.\033[0m"
echo -e "    Start with: \033[1;36m./start_all.sh --hot\033[0m or \033[1;36m./start_hot.sh\033[0m"
exit 1
