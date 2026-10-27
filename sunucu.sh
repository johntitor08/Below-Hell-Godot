#!/bin/bash
# Below Hell sunucusunu başlatır. Kullanım: ./sunucu.sh [port]
cd "$(dirname "$0")"
exec flatpak run org.godotengine.Godot --headless --path . -- --server --port="${1:-7788}"
