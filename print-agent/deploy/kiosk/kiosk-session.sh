#!/usr/bin/env bash
set -euo pipefail
# One launcher per graphical user, even if two startup entries exist.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/achuppori-kiosk-$(id -u).lock"
flock -n 9 || exit 0
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true
BROWSER=$(command -v chromium || command -v chromium-browser || true)
[[ -n "$BROWSER" ]] || { echo "Install Chromium first."; exit 1; }
# Dedicated profile isolates this kiosk from any ordinary desktop browser.
while true; do
    # Never navigate to a connection-error page during a slow boot.
    until curl -fsS --max-time 3 http://127.0.0.1:5001/kiosk >/dev/null; do
        sleep 1
    done
    "$BROWSER" --kiosk --password-store=basic --disable-gpu --noerrdialogs --disable-infobars --disable-session-crashed-bubble \
        --user-data-dir="${XDG_RUNTIME_DIR:-/tmp}/achuppori-kiosk-profile-$(id -u)" --disable-background-networking \
        --disable-component-update --disable-sync --no-first-run --disable-extensions --disk-cache-size=10485760 \
        --window-position=0,0 --window-size=800,480 http://127.0.0.1:5001/kiosk || true
    echo "Kiosk browser exited; reopening after five seconds."
    sleep 5
done
