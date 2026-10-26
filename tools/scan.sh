#!/bin/bash
cd "$(dirname "$0")/.."
timeout 600 flatpak run org.godotengine.Godot --headless --path . --editor --quit > /dev/null 2>&1
