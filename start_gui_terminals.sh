#!/usr/bin/env bash
# ==============================================================================
# Autonomous Print Hub - Desktop Terminal Consoles Launcher (Ubuntu)
# Opens live visual terminal windows directly on your screen.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/flutter/bin:$PATH"

# 1. Kill any existing instances on ports 8000, 5000, 3000
fuser -k 8000/tcp 2>/dev/null || true
fuser -k 5000/tcp 2>/dev/null || true
fuser -k 3000/tcp 2>/dev/null || true

echo "Launching 3 Live Terminal Console Windows on your screen..."

# Window 1: FastAPI Backend
gnome-terminal --geometry=80x25+50+50 --title="[1] FastAPI Backend (Port 8000)" -- bash -c "
  echo -e '\033[1;32m=====================================================\033[0m'
  echo -e '\033[1;32m   [BACKEND] FastAPI REST API (Port 8000)            \033[0m'
  echo -e '\033[1;32m   Docs:  http://127.0.0.1:8000/docs                 \033[0m'
  echo -e '\033[1;32m   Kiosk: http://127.0.0.1:8000/kiosk               \033[0m'
  echo -e '\033[1;32m=====================================================\033[0m'
  echo ''
  cd '$SCRIPT_DIR/backend' && '$SCRIPT_DIR/venv/bin/uvicorn' app.main:app --host 127.0.0.1 --port 8000 --reload
  exec bash
"

# Window 2: Flask Print Agent & CUPS
gnome-terminal --geometry=80x25+650+50 --title="[2] Flask Print Agent (Port 5000)" -- bash -c "
  echo -e '\033[1;34m=====================================================\033[0m'
  echo -e '\033[1;34m   [PRINT AGENT] Hardware CUPS Controller (Port 5000)\033[0m'
  echo -e '\033[1;34m   Printer: HP_LaserJet_400_M401dn_F36EC0            \033[0m'
  echo -e '\033[1;34m   Address: socket://169.254.71.179:9100             \033[0m'
  echo -e '\033[1;34m=====================================================\033[0m'
  echo ''
  cd '$SCRIPT_DIR/print-agent' && '$SCRIPT_DIR/venv/bin/python' app/main.py
  exec bash
"

# Window 3: Flutter Web Application
gnome-terminal --geometry=80x25+350+450 --title="[3] Flutter Frontend (Port 3000)" -- bash -c "
  echo -e '\033[1;36m=====================================================\033[0m'
  echo -e '\033[1;36m   [FRONTEND] Flutter Web App (Port 3000)            \033[0m'
  echo -e '\033[1;36m   URL: http://127.0.0.1:3000                         \033[0m'
  echo -e '\033[1;36m=====================================================\033[0m'
  echo ''
  cd '$SCRIPT_DIR/frontend' && '$SCRIPT_DIR/venv/bin/python' -m http.server 3000 --bind 127.0.0.1 --directory build/web
  exec bash
"

echo "Terminals launched on your screen!"
