#!/usr/bin/env bash
# ==============================================================================
# Autonomous Printer - Standalone Package Bundler for Raspberry Pi
# Creates a clean, minimal archive with zero test/dev/backend dependencies.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$AGENT_DIR/dist"
ARCHIVE_NAME="print-agent-pi-standalone.tar.gz"

echo "Creating clean standalone package for Raspberry Pi 3 Model B..."
mkdir -p "$OUTPUT_DIR"

# Create archive excluding dev artifacts, tests, caches, and local environments
tar -czvf "$OUTPUT_DIR/$ARCHIVE_NAME" \
    --exclude="tests" \
    --exclude="__pycache__" \
    --exclude="*.pyc" \
    --exclude="*.pyo" \
    --exclude="venv" \
    --exclude=".venv" \
    --exclude=".pytest_cache" \
    --exclude=".env" \
    --exclude="storage/*" \
    --exclude="logs/*" \
    --exclude="dist" \
    --exclude=".git*" \
    -C "$AGENT_DIR" \
    app deploy scripts .env.example requirements.txt DEPLOYMENT.md README.md

echo "Standalone deployment package created: $OUTPUT_DIR/$ARCHIVE_NAME"
ls -lh "$OUTPUT_DIR/$ARCHIVE_NAME"
