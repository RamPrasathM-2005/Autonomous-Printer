#!/usr/bin/env bash
# ==============================================================================
# Achuppori - Build and Package Mobile APK
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
DOWNLOADS_DIR="$SCRIPT_DIR/downloads"
STATIC_DIR="$SCRIPT_DIR/print-agent/app/static"

mkdir -p "$DOWNLOADS_DIR"
mkdir -p "$STATIC_DIR"

echo -e "\033[1;36m[*] Building optimized Android Release APK (Flutter)...\033[0m"
cd "$FRONTEND_DIR"

# Tunnel configuration uses a build definition.
CURRENT_TUNNEL=""
if [ -f "$SCRIPT_DIR/storage/tunnel_url.txt" ]; then
    CURRENT_TUNNEL=$(tr -d '\r\n' < "$SCRIPT_DIR/storage/tunnel_url.txt")
fi
flutter pub get --enforce-lockfile
flutter build apk --split-per-abi --no-pub "--dart-define=ACTIVE_TUNNEL_URL=$CURRENT_TUNNEL"

SOURCE_APK="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [ ! -f "$SOURCE_APK" ]; then
    SOURCE_APK="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
fi

if [ -f "$SOURCE_APK" ]; then
    echo -e "\033[1;32m[*] Copying updated APK to distribution targets...\033[0m"
    cp -f "$SOURCE_APK" "$DOWNLOADS_DIR/achuppori.apk"
    cp -f "$SOURCE_APK" "$STATIC_DIR/achuppori.apk"
    
    APK_SIZE=$(ls -lh "$DOWNLOADS_DIR/achuppori.apk" | awk '{print $5}')
    echo -e "\033[1;32m[✓] Updated APK ready for download! ($APK_SIZE)\033[0m"
    echo -e "    - $DOWNLOADS_DIR/achuppori.apk"
    echo -e "    - $STATIC_DIR/achuppori.apk"
else
    echo -e "\033[1;31m[!] APK output file not found.\033[0m"
    exit 1
fi
