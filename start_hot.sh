#!/usr/bin/env bash
# ==============================================================================
# Achuppori - Start with Live Flutter Hot-Reload
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/start_all.sh" --hot "$@"
