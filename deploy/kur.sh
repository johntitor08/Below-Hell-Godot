#!/bin/bash
# Below Hell sunucusunu bu bilgisayara systemd kullanıcı servisi olarak kurar ya da günceller.
# Kullanım: ./deploy/kur.sh [port]   (varsayılan 7788/UDP)
set -euo pipefail
D="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-7788}"
HEDEF="$HOME/.local/share/belowhell-sunucu"
KAYIT="$HOME/.local/share/godot/app_userdata/Below Hell"

echo "== Linux sürümü derleniyor"
mkdir -p "$D/build/linux"
flatpak run org.godotengine.Godot --headless --path "$D" --export-release "Linux" "$D/build/linux/BelowHell.x86_64" > /dev/null 2>&1

if systemctl --user is-active --quiet belowhell-sunucu; then
	echo "== Çalışan sunucu durduruluyor (kayıt korunur)"
	systemctl --user stop belowhell-sunucu
	[ -f "$KAYIT/server_db.json" ] && cp "$KAYIT/server_db.json" "$KAYIT/server_db.yedek-$(date +%Y%m%d-%H%M%S).json"
fi

mkdir -p "$HEDEF" "$HOME/.config/systemd/user"
cp "$D/build/linux/BelowHell.x86_64" "$HEDEF/"
cat > "$HOME/.config/systemd/user/belowhell-sunucu.service" <<UNIT
[Unit]
Description=Below Hell oyun sunucusu (yerel)
After=network-online.target

[Service]
WorkingDirectory=%h/.local/share/belowhell-sunucu
ExecStartPre=/bin/rm -f "%h/.local/share/godot/app_userdata/Below Hell/kapat"
ExecStart=/usr/bin/stdbuf -oL -eL %h/.local/share/belowhell-sunucu/BelowHell.x86_64 --headless -- --server --port=$PORT
ExecStop=/bin/sh -c 'touch "%h/.local/share/godot/app_userdata/Below Hell/kapat"; for i in \$\$(seq 1 20); do kill -0 \${MAINPID} 2>/dev/null || exit 0; sleep 0.5; done'
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now belowhell-sunucu
sleep 3
systemctl --user --no-pager status belowhell-sunucu | head -5
ss -ulnp | grep ":$PORT " || echo "UYARI: $PORT/UDP dinlenmiyor, logu kontrol et: journalctl --user -u belowhell-sunucu"
echo
echo "Tamam. Resmi adres: malls-correctly.tun.ply.gg:30451 (playit UDP tüneli → 127.0.0.1:$PORT)"
