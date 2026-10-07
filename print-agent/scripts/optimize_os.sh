#!/usr/bin/env bash
# ==============================================================================
# Autonomous Printer - Raspberry Pi 3 Model B Operating System Optimization
# Configures a lean, high-reliability, 24/7 production kiosk runtime.
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This optimization script must be run as root (use sudo)."
    exit 1
fi

echo "=================================================================="
echo " Starting Raspberry Pi 3 Model B OS Optimization for 24/7 Kiosk"
echo "=================================================================="

# 1. Disable Unnecessary System Services
echo "[1/4] Disabling non-essential services..."

SERVICES_TO_DISABLE=(
    bluetooth.service
    hciuart.service
    bluealsa.service
    ModemManager.service
    cups-browsed.service
    apt-daily.timer
    apt-daily-upgrade.timer
    triggerhappy.service
)

for svc in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl list-unit-files "$svc" &>/dev/null; then
        echo " - Stopping and disabling $svc"
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        systemctl mask "$svc" 2>/dev/null || true
    fi
done

# Ensure essential CUPS service is enabled
echo " - Ensuring core CUPS print daemon is active..."
systemctl unmask cups.service 2>/dev/null || true
systemctl enable cups.service
systemctl restart cups.service

# 2. Kernel and Memory Tuning for 1GB RAM & SSD Protection
echo "[2/4] Applying memory and SSD preservation sysctl rules..."

SYSCTL_CONF="/etc/sysctl.d/99-printagent.conf"
cat << 'EOF' > "$SYSCTL_CONF"
# Raspberry Pi 3B Low-Memory & SSD Optimization
# Minimize swap usage to prolong 32GB SSD lifetime
vm.swappiness=10
# Cache reclaim balance
vm.vfs_cache_pressure=50
# Write dirty pages to SSD promptly to avoid memory spikes
vm.dirty_background_ratio=5
vm.dirty_ratio=10
EOF

sysctl -p "$SYSCTL_CONF" 2>/dev/null || true

# 3. Optimize GPU Memory Allocation in config.txt
echo "[3/4] Optimizing GPU memory for SmartiPi Touch Display (800x480)..."

CONFIG_FILE=""
if [ -f "/boot/firmware/config.txt" ]; then
    CONFIG_FILE="/boot/firmware/config.txt"
elif [ -f "/boot/config.txt" ]; then
    CONFIG_FILE="/boot/config.txt"
fi

if [ -n "$CONFIG_FILE" ]; then
    # Set GPU memory to 96MB (sufficient for Chromium GUI acceleration, leaves ~928MB RAM for OS & apps)
    if grep -q "^gpu_mem=" "$CONFIG_FILE"; then
        sed -i 's/^gpu_mem=.*/gpu_mem=96/' "$CONFIG_FILE"
    else
        echo "gpu_mem=96" >> "$CONFIG_FILE"
    fi

    # Disable screen blanking at firmware level
    if ! grep -q "^hdmi_blanking=" "$CONFIG_FILE"; then
        echo "hdmi_blanking=0" >> "$CONFIG_FILE"
    fi
    echo " - Updated GPU memory and display parameters in $CONFIG_FILE"
else
    echo " - Note: config.txt not detected (non-standard firmware layout). Skipping config.txt edit."
fi

# 4. Disable Console Screen Blanking in cmdline.txt
echo "[4/4] Configuring console blanking prevention..."
CMDLINE_FILE=""
if [ -f "/boot/firmware/cmdline.txt" ]; then
    CMDLINE_FILE="/boot/firmware/cmdline.txt"
elif [ -f "/boot/cmdline.txt" ]; then
    CMDLINE_FILE="/boot/cmdline.txt"
fi

if [ -n "$CMDLINE_FILE" ]; then
    if ! grep -q "consoleblank=0" "$CMDLINE_FILE"; then
        sed -i 's/$/ consoleblank=0/' "$CMDLINE_FILE"
        echo " - Added consoleblank=0 to $CMDLINE_FILE"
    fi
fi

echo "=================================================================="
echo " Raspberry Pi OS Optimization Complete!"
echo " A system reboot is recommended for kernel & GPU memory settings."
echo "=================================================================="
