# Below Hell — Godot

Unity'deki *Below Hell*'in Godot 4.6 ile yeniden tasarlanmış hâli: Öz topla, 20 hayvan formuna dönüş, cehennemin altından tırman.

- `game/creature/` — CharacterBody2D yaratık, girdi kaynakları, Öz/dönüşüm sistemi.
- `game/abilities/` — 20 formun yetenekleri (dil kancası, ekolokasyon, boynuz hücumu, alev nefesi…).
- `game/world/` — ASCII bölüm kurucusu, dünya nesneleri; bölümler `tools/make_levels.py` ile üretilir.
- `game/ui/` — ana menü, HUD, radyal dönüşüm menüsü, tema.

Kontroller: A/D hareket, Boşluk zıplama, J saldırı, K/L yetenek, Q (basılı) dönüşüm, R formu bırak, Esc duraklat.

Çalıştırma: projeyi Godot 4.6 ile açıp oynat.
