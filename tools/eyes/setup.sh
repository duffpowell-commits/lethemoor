#!/usr/bin/env bash
# One-time setup per cloud session: Node deps for tools/eyes (pinned in package-lock.json).
# Godot itself: see AGENTS.md "Godot in a cloud sandbox". Needs xvfb-run for a display.
set -euo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "EYES SETUP FAIL: node not found"; exit 1; }
command -v xvfb-run >/dev/null || { echo "EYES SETUP FAIL: xvfb-run not found (apt-get install -y xvfb)"; exit 1; }
command -v godot >/dev/null || { echo "EYES SETUP FAIL: godot not on PATH (AGENTS.md: Godot in a cloud sandbox)"; exit 1; }
npm ci --silent --no-audit --no-fund
echo "EYES SETUP PASS"
