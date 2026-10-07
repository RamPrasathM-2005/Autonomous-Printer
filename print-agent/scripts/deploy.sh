#!/usr/bin/env bash
# ==============================================================================
# Autonomous Printer - Production Deployment Script
# Target: Raspberry Pi 3 Model B (Debian / Raspberry Pi OS)
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Deployment script must be run with sudo or as root."
    echo "Usage: sudo bash scripts/deploy.sh [TARGET_USER]"
    exit 1
fi

TARGET_USER="${1:-${SUDO_USER:-pi}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=================================================================="
echo " Deploying Autonomous Print Agent on Raspberry Pi 3 Model B"
echo " Target Directory: $AGENT_DIR"
echo " Execution User:   $TARGET_USER"
echo "=================================================================="

# 1. Install OS Dependencies
echo "[1/10] Installing required system packages via apt..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cups \
    libcups2-dev \
    python3-venv \
    python3-pip \
    python3-dev \
    build-essential \
    chromium-browser \
    x11-xserver-utils \
    unclutter \
    curl

# 2. Configure CUPS Daemon & Permissions
echo "[2/10] Configuring CUPS daemon and user groups..."
systemctl unmask cups.service 2>/dev/null || true
systemctl enable cups.service
systemctl restart cups.service

# Add user to printing groups
usermod -a -G lp "$TARGET_USER" 2>/dev/null || true
usermod -a -G lpadmin "$TARGET_USER" 2>/dev/null || true

# 3. Create Required Directory Hierarchy
echo "[3/10] Initializing storage, spool, and logging directories..."
mkdir -p "$AGENT_DIR/storage/processed_jobs"
mkdir -p "$AGENT_DIR/logs"

# 4. Initialize Python Virtual Environment
echo "[4/10] Setting up Python virtual environment..."
if [ ! -d "$AGENT_DIR/venv" ]; then
    sudo -u "$TARGET_USER" python3 -m venv "$AGENT_DIR/venv"
fi

# 5. Install Python Packages
echo "[5/10] Installing production Python packages..."
sudo -u "$TARGET_USER" "$AGENT_DIR/venv/bin/pip" install --upgrade pip setuptools wheel
sudo -u "$TARGET_USER" "$AGENT_DIR/venv/bin/pip" install -r "$AGENT_DIR/requirements.txt"

# 6. Secure Environment Configuration
echo "[6/10] Checking environment configuration (.env)..."
if [ ! -f "$AGENT_DIR/.env" ]; then
    if [ -f "$AGENT_DIR/.env.example" ]; then
        echo " - Creating .env from .env.example template..."
        cp "$AGENT_DIR/.env.example" "$AGENT_DIR/.env"
    else
        touch "$AGENT_DIR/.env"
    fi
fi
# Restrict permissions on credentials
chmod 600 "$AGENT_DIR/.env"
chown -R "$TARGET_USER:$TARGET_USER" "$AGENT_DIR"

# 7. Configure Log Rotation
echo "[7/10] Installing logrotate configuration..."
LOGROTATE_SRC="$AGENT_DIR/deploy/logrotate/print-agent"
if [ -f "$LOGROTATE_SRC" ]; then
    # Customize logrotate with actual directory path
    sed "s|/home/pi/print-agent|$AGENT_DIR|g" "$LOGROTATE_SRC" > /etc/logrotate.d/print-agent
    chmod 644 /etc/logrotate.d/print-agent
fi

# 8. Configure Systemd Service
echo "[8/10] Installing and enabling systemd unit..."
SYSTEMD_SRC="$AGENT_DIR/deploy/systemd/print-agent.service"
SYSTEMD_DEST="/etc/systemd/system/print-agent.service"

sed \
    -e "s|User=pi|User=$TARGET_USER|g" \
    -e "s|/home/pi/print-agent|$AGENT_DIR|g" \
    "$SYSTEMD_SRC" > "$SYSTEMD_DEST"

chmod 644 "$SYSTEMD_DEST"
systemctl daemon-reload
systemctl enable print-agent.service

# 9. Configure Chromium Kiosk Auto-start
echo "[9/10] Configuring Chromium kiosk startup for SmartiPi Touch..."
chmod +x "$AGENT_DIR/deploy/kiosk/kiosk-session.sh"

# Update path in session launcher if installed outside /home/pi
sed -i "s|/home/pi/print-agent|$AGENT_DIR|g" "$AGENT_DIR/deploy/kiosk/kiosk-session.sh"

# Install desktop autostart entry for all sessions
mkdir -p /etc/xdg/autostart
sed \
    -e "s|/home/pi/print-agent|$AGENT_DIR|g" \
    "$AGENT_DIR/deploy/kiosk/kiosk-autostart.desktop" > /etc/xdg/autostart/kiosk.desktop
chmod 644 /etc/xdg/autostart/kiosk.desktop

# Also place in user autostart for LXDE / Openbox
USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [ -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME/.config/autostart"
    cp /etc/xdg/autostart/kiosk.desktop "$USER_HOME/.config/autostart/kiosk.desktop"
    chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.config/autostart"
fi

# 10. Start Service and Execute Pre-flight Verifications
echo "[10/10] Starting Print Agent and verifying status..."
systemctl restart print-agent.service

# Wait for daemon to respond
echo " - Awaiting daemon initialization..."
HEALTHY=false
for i in {1..15}; do
    if curl -s --max-time 2 http://127.0.0.1:5001/health | grep -q "healthy"; then
        HEALTHY=true
        break
    fi
    sleep 1
done

echo "=================================================================="
if [ "$HEALTHY" = true ]; then
    echo " ✅ Print Agent deployed and verified successfully!"
    echo " - Daemon Status:   $(systemctl is-active print-agent.service)"
    echo " - Health Check:    HTTP 200 (http://127.0.0.1:5001/health)"
    echo " - Kiosk Interface: http://127.0.0.1:5001/kiosk"
    echo " - CUPS Daemon:     $(systemctl is-active cups)"
else
    echo " ⚠️ Print Agent started, but health check is still initializing."
    echo " Check daemon logs using: journalctl -u print-agent.service -n 50"
fi
echo "=================================================================="
