#!/bin/bash
# Tarayıcı sürümünün Cloudflare tünelini systemd kullanıcı servisi olarak kurar ve başlatır.
# Önce ./deploy/kur.sh ile sunucu kurulmuş olmalı (WebSocket portu 7789).
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || { echo "gh oturumu yok: gh auth login"; exit 1; }
[ -x "$HOME/.local/bin/cloudflared" ] || { echo "~/.local/bin/cloudflared bulunamadı"; exit 1; }
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
cp "$D/web-tunel.sh" "$HOME/.local/bin/belowhell-web-tunel.sh"
chmod +x "$HOME/.local/bin/belowhell-web-tunel.sh"
cat > "$HOME/.config/systemd/user/belowhell-web-tunel.service" <<'UNIT'
[Unit]
Description=Below Hell tarayıcı sürümü için Cloudflare tüneli (wss)
After=network-online.target belowhell-sunucu.service

[Service]
ExecStart=%h/.local/bin/belowhell-web-tunel.sh
Restart=always
RestartSec=10
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=LC_ALL=C

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now belowhell-web-tunel
echo "Tünel başlatıldı; adres birkaç saniye içinde yayınlanır:"
for i in $(seq 1 30); do
	grep -q "adres yayınlandı" "$HOME/.local/state/belowhell-tunel.log" 2>/dev/null && break
	sleep 2
done
grep "adres yayınlandı" "$HOME/.local/state/belowhell-tunel.log" | tail -1 || echo "Henüz yok; izlemek için: tail -f ~/.local/state/belowhell-tunel.log"
