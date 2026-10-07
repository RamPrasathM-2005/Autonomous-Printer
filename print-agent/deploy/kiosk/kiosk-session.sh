#!/usr/bin/env bash
# ==============================================================================
# Autonomous Printer - SmartiPi Touch Kiosk Launcher
# Target: Raspberry Pi 3 Model B (800x480 SmartiPi Touch Display)
# ==============================================================================

set -u

KIOSK_URL="http://127.0.0.1:5001/kiosk"
HEALTH_URL="http://127.0.0.1:5001/health"

# 1. Disable screen blanking, power management, and screen savers
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# 2. Hide mouse cursor when idle on touchscreen
if command -v unclutter &>/dev/null; then
    killall unclutter 2>/dev/null || true
    unclutter -idle 0.5 -root &
fi

# 3. Wait for Print Agent daemon to become healthy before opening kiosk
echo "[KIOSK] Waiting for Print Agent daemon on $HEALTH_URL..."
MAX_WAIT=45
WAIT_COUNT=0
while ! curl -s --max-time 2 "$HEALTH_URL" | grep -q "healthy"; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ "$WAIT_COUNT" -ge "$MAX_WAIT" ]; then
        echo "[KIOSK] Timed out waiting for agent health. Proceeding to launch..."
        break
    fi
done

# 4. Clean up any stale Chromium lock files and crash flags from unexpected power losses
CHROMIUM_DIR="$HOME/.config/chromium"
if [ -d "$CHROMIUM_DIR" ]; then
    rm -f "$CHROMIUM_DIR/SingletonLock" "$CHROMIUM_DIR/SingletonSocket" "$CHROMIUM_DIR/SingletonCookie" 2>/dev/null || true
    # Reset exit_type from Crashed to Normal so no restore bubble shows
    PREF_FILE="$CHROMIUM_DIR/Default/Preferences"
    if [ -f "$PREF_FILE" ]; then
        sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$PREF_FILE" 2>/dev/null || true
        sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$PREF_FILE" 2>/dev/null || true
    fi
fi

# 5. Determine browser binary
BROWSER_BIN=""
if command -v chromium-browser &>/dev/null; then
    BROWSER_BIN="chromium-browser"
elif command -v chromium &>/dev/null; then
    BROWSER_BIN="chromium"
else
    echo "[KIOSK ERROR] Neither chromium-browser nor chromium was found!"
    exit 1
fi

echo "[KIOSK] Launching $BROWSER_BIN in kiosk mode on $KIOSK_URL..."

# 6. Persistent respawn loop for 24/7 continuous uptime
while true; do
    "$BROWSER_BIN" \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --incognito \
        --check-for-update-interval=31536000 \
        --disable-translate \
        --disable-features=TranslateUI \
        --disable-pinch \
        --overscroll-history-navigation=0 \
        --touch-events=enabled \
        --disable-dev-shm-usage \
        --disable-background-networking \
        --disable-component-update \
        --disable-sync \
        --disk-cache-dir=/tmp/chromium-kiosk-cache \
        --disk-cache-size=10485760 \
        --window-position=0,0 \
        --window-size=800,480 \
        "$KIOSK_URL"

    echo "[KIOSK] Browser closed or crashed. Restarting in 2 seconds..."
    sleep 2
done
