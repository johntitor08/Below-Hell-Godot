class_name UContentSizeFitter
extends Mono

var horizontalFit := 0
var verticalFit := 0

func _on_injected(_root: Node) -> void:
	horizontalFit = int(u.get("m_HorizontalFit", 0))
	verticalFit = int(u.get("m_VerticalFit", 0))

func OnEnable() -> void:
	ES.mark_layout_dirty()

func set_layout(axis: int) -> void:
	var fit := horizontalFit if axis == 0 else verticalFit
	if fit == 0:
		return
	var go: Control = gameObject
	var p := ES.layout_props(go, axis)
	var s: float = p[0] if fit == 1 else p[1]
	RT.set_size_with_current_anchors(go, axis, s)
