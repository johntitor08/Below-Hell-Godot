class_name UCanvasGroup
extends Mono

var _alpha := 1.0
var interactable := true
var blocksRaycasts := true
var ignoreParentGroups := false

var alpha: float:
	get:
		return _alpha
	set(v):
		_alpha = clampf(v, 0.0, 1.0)
		_apply()

func _on_injected(_root: Node) -> void:
	_alpha = float(u.get("m_Alpha", 1))
	interactable = int(u.get("m_Interactable", 1)) != 0
	blocksRaycasts = int(u.get("m_BlocksRaycasts", 1)) != 0
	ignoreParentGroups = int(u.get("m_IgnoreParentGroups", 0)) != 0
	_apply()

func _apply() -> void:
	var go = get_parent()
	if go is CanvasItem:
		var m: Color = go.modulate
		m.a = _alpha if _enabled_flag else 1.0
		go.modulate = m

func OnEnable() -> void:
	_apply()

func OnDisable() -> void:
	var go = get_parent()
	if go is CanvasItem:
		var m: Color = go.modulate
		m.a = 1.0
		go.modulate = m

func blocksRaycasts_effective() -> bool:
	return blocksRaycasts or not _enabled_flag
