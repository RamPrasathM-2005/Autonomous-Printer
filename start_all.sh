#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"
if [[ ! -x "$PROJECT_ROOT/.venv/bin/python" ]]; then
    echo "Run python3 scripts/project.py setup first." >&2
    exit 1
fi
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --build|-build|-Build|-b) ARGS+=(--build) ;;
        --hot|--dev|-d|--hot-reload|--hotreload) ARGS+=(--hot) ;;
        --no-agent|--noagent|-na) ARGS+=(--no-agent) ;;
        --no-tunnel|--notunnel|-nt|--prod|--static) ;;
        *) echo "Unsupported option: $arg. Use --build, --hot, or --no-agent." >&2; exit 1 ;;
    esac
done
exec "$PROJECT_ROOT/.venv/bin/python" scripts/project.py run "${ARGS[@]}"
