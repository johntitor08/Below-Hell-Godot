#!/bin/bash
cd "$(dirname "$0")/.."
out="${1:-$PWD/.shots/shot.png}"; shift
timeout 120 flatpak run org.godotengine.Godot --path . --windowed --resolution 1920x1080 -- --shot="$out" "$@" 2>&1 | grep -v "^\s*at:" | grep -E "ERROR|SHOT|WARNING" | sort | uniq -c | sort -rn | head -40
