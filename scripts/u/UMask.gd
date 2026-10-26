class_name UMask
extends Mono

var showMaskGraphic := true

func _on_injected(_root: Node) -> void:
	showMaskGraphic = int(u.get("m_ShowMaskGraphic", 1)) != 0
	_apply(_enabled_flag)

func _apply(on: bool) -> void:
	var go = get_parent()
	if go is Control:
		go.clip_contents = on
	if go is UImage and str(u.get("$type", "")) == "Mask":
		go.show_graphic = showMaskGraphic or not on
		go.queue_redraw()

func OnEnable() -> void:
	_apply(true)

func OnDisable() -> void:
	_apply(false)
