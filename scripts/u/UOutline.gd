class_name UOutline
extends Mono

var effectColor := Color(0, 0, 0, 0.5)
var effectDistance := Vector2(1, -1)

func _on_injected(root: Node) -> void:
	var c = DB.conv(u.get("m_EffectColor"), root)
	if c is Color:
		effectColor = c
	var d = DB.conv(u.get("m_EffectDistance"), root)
	if d is Vector2:
		effectDistance = d

func OnEnable() -> void:
	var go = get_parent()
	if go is UText and go.label != null:
		go.label.add_theme_constant_override("outline_size", int(max(absf(effectDistance.x), absf(effectDistance.y)) * 2))
		go.label.add_theme_color_override("font_outline_color", effectColor)

func OnDisable() -> void:
	var go = get_parent()
	if go is UText and go.label != null:
		go.label.remove_theme_constant_override("outline_size")
