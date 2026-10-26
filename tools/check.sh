#!/bin/bash
cd "$(dirname "$0")/.."
timeout 300 flatpak run org.godotengine.Godot --headless --path . --editor --quit 2>&1 | grep -A1 "SCRIPT ERROR\|Parse Error" | grep -v "^--$" | paste - - | sed 's/\s\+at: / @ /' | sort -u
