#!/usr/bin/env bash
# ==============================================================================
# Autonomous Print Station - Kiosk Display Launcher
# Launches the OTP terminal in full-screen kiosk mode
# ==============================================================================

KIOSK_URL="http://127.0.0.1:5001/kiosk"

if command -v chromium &>/dev/null; then
    echo "Launching Kiosk using Chromium..."
    chromium --kiosk --noerrdialogs --disable-infobars --check-for-update-interval=31536000 "$KIOSK_URL"
elif command -v chromium-browser &>/dev/null; then
    echo "Launching Kiosk using Chromium Browser..."
    chromium-browser --kiosk --noerrdialogs --disable-infobars --check-for-update-interval=31536000 "$KIOSK_URL"
elif command -v google-chrome &>/dev/null; then
    echo "Launching Kiosk using Google Chrome..."
    google-chrome --kiosk --noerrdialogs --disable-infobars "$KIOSK_URL"
elif command -v firefox &>/dev/null; then
    echo "Launching Kiosk using Firefox in kiosk mode..."
    firefox --kiosk "$KIOSK_URL"
else
    echo "No supported browser found for kiosk mode."
    echo "To install Chromium, run: sudo apt update && sudo apt install -y chromium-browser"
    echo "Or open $KIOSK_URL in any web browser."
fi
