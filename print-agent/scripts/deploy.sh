#!/usr/bin/env bash
# Install the configured agent on Raspberry Pi OS / Ubuntu (graphical kiosk optional).
set -euo pipefail
[[ $(id -u) == 0 ]] || { echo "Run with sudo: sudo bash print-agent/scripts/deploy.sh USER"; exit 1; }
TARGET_USER="${1:-${SUDO_USER:-pi}}"
id "$TARGET_USER" >/dev/null
AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$AGENT_DIR" =~ ^[a-zA-Z0-9_./-]+$ ]] || { echo "Install under a path without spaces or shell metacharacters."; exit 1; }
[[ -f "$AGENT_DIR/.env" ]] || { echo "Copy .env.example to .env and configure station credentials first."; exit 1; }
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cups libcups2-dev python3-venv python3-dev build-essential curl
systemctl enable --now cups
cupsctl PreserveJobHistory=Yes PreserveJobFiles=No
usermod -a -G lp,lpadmin "$TARGET_USER"
mkdir -p "$AGENT_DIR/storage" "$AGENT_DIR/logs"
chown -R "$TARGET_USER:$(id -gn "$TARGET_USER")" "$AGENT_DIR"
chmod 600 "$AGENT_DIR/.env"
sudo -u "$TARGET_USER" python3 -m venv "$AGENT_DIR/venv"
sudo -u "$TARGET_USER" "$AGENT_DIR/venv/bin/python" -m pip install -r "$AGENT_DIR/requirements.txt"
# Parse dotenv with Python, never source arbitrary .env shell code.
PORT=$(sudo -u "$TARGET_USER" "$AGENT_DIR/venv/bin/python" - "$AGENT_DIR" <<'PY'
import sys
from pathlib import Path
from dotenv import dotenv_values
v = dotenv_values(Path(sys.argv[1]) / '.env')
for key in ('AGENT_ID', 'AGENT_TOKEN', 'BACKEND_URL', 'KIOSK_WEB_URL'):
    value = v.get(key, '')
    if not value or 'CHANGE_ME' in value or 'example.edu' in value:
        raise SystemExit('Configure ' + key + ' before deployment')
if v.get('MOCK_CUPS', 'false').lower() in ('true', '1', 'yes'):
    raise SystemExit('Set MOCK_CUPS=false for physical deployment')
port = int(v.get('PORT', '5001'))
if port != 5001:
    raise SystemExit('Kiosk deployment requires PORT=5001')
print(port)
PY
)
sed -e "s|User=pi|User=$TARGET_USER|" -e "s|/home/pi/print-agent|$AGENT_DIR|g" "$AGENT_DIR/deploy/systemd/print-agent.service" > /etc/systemd/system/print-agent.service
systemctl daemon-reload
systemctl enable print-agent.service
systemctl restart print-agent.service
# A single per-user autostart, with a launch lock preventing duplicate browser loops.
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if command -v chromium >/dev/null || command -v chromium-browser >/dev/null; then
    mkdir -p "$USER_HOME/.config/autostart"
    sed "s|/home/pi/print-agent|$AGENT_DIR|g" "$AGENT_DIR/deploy/kiosk/kiosk-autostart.desktop" > "$USER_HOME/.config/autostart/kiosk.desktop"
    chown "$TARGET_USER:$(id -gn "$TARGET_USER")" "$USER_HOME/.config/autostart/kiosk.desktop"
    # Remove only this project's historical global startup entry.
    if [[ -f /etc/xdg/autostart/kiosk.desktop ]] && grep -q 'Achuppori Kiosk' /etc/xdg/autostart/kiosk.desktop; then
        rm /etc/xdg/autostart/kiosk.desktop
    fi
    # Disable the other historical launcher, preserving it for inspection.
    LEGACY_KIOSK="$USER_HOME/.config/autostart/smartprint-kiosk.desktop"
    if [[ -f "$LEGACY_KIOSK" ]] && grep -q '/SmartPrint/launch_kiosk.sh' "$LEGACY_KIOSK"; then
        mv "$LEGACY_KIOSK" "$LEGACY_KIOSK.disabled"
    fi
else
    echo "Agent installed. Install chromium on a graphical Pi OS desktop to enable the touchscreen kiosk, then rerun."
fi
for attempt in {1..30}; do
    if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" >/dev/null; then
        echo "Agent healthy. Check admin heartbeat/discovered queues; log out/in for kiosk autostart."
        exit 0
    fi
    sleep 1
done
journalctl -u print-agent.service -n 40 --no-pager
exit 1
