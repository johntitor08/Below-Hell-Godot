# Below Hell — Godot

İndir: https://johntitortheprog.itch.io/below-hell (Linux, Windows)

Unity'deki *Below Hell*'in Godot 4.6 ile yeniden tasarlanmış hâli: Öz topla, 20 hayvan formuna dönüş, cehennemin altından tırman.

## Modlar
- **Macera** — beş bölüm; her birinin anahtarı farklı bir form: zıplama (Kurbağa), su altı (Aksolotl/Yılan Balığı), karanlık (Yarasa), kırılabilir duvarlar (Geyik/Ayı), bekçi boss'u.
- **Arena** — bilgisayara karşı, aynı klavyede iki kişi ya da online; 3 raund.
- **Bestiyer** ve **Ayarlar** (ses, tam ekran, sarsıntı, Türkçe/English).

## Kontroller
A/D hareket · Boşluk zıplama · J saldırı · K / L yetenekler · Q (basılı) dönüşüm · R formu bırak (yarı iade) · Esc duraklat. Gamepad desteklenir.
Yerel düelloda 1. oyuncu WASD + F/G/H, 2. oyuncu oklar + ./,

## Online
Aynı proje başsız sunucu olarak çalışır:

```bash
./sunucu.sh            # varsayılan port 7788
```

Sürekli açık sunucu (bu bilgisayarda, systemd kullanıcı servisi; aynı komut günceller):

```bash
./deploy/kur.sh        # derler, kurar, başlatır
./deploy/log.sh        # canlı log
```

İnternete açmak için playit.gg panelinde **UDP** tüneli ekle, yerel adres `127.0.0.1:7788`.

Oyun varsayılan olarak resmi sunucuya (`malls-correctly.tun.ply.gg:30451`) bağlanır; kendi sunucun için Online Arena ekranında ip:port gir. Kayıt ol, sonra "Eşleşme Bul". Sunucu hesapları, eşleştirmeyi, galibiyet kayıtlarını ve bölüm sürelerinin liderlik tablosunu tutar (`user://server_db.json`). Bağlantı şifresizdir (ENet); şifreler istemcide hash'lenip sunucuda tuzla yeniden hash'lenir.

## Yapı
- `game/creature/` — CharacterBody2D yaratık, girdi kaynakları (oyuncu, bot, ağ), Öz/dönüşüm.
- `game/abilities/` — 20 formun yetenekleri.
- `game/world/` — bölüm kurucusu ve dünya nesneleri; bölümler `python3 tools/make_levels.py` ile üretilir.
- `game/arena/`, `game/net/`, `game/ui/` — arena, ağ/sunucu, arayüz.
