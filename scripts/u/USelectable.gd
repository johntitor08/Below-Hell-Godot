class_name USelectable
extends Mono

var _interactable := true
var transition := 1
var _colors := {
	"normalColor": Color.WHITE,
	"highlightedColor": Color(0.96, 0.96, 0.96, 1),
	"pressedColor": Color(0.78, 0.78, 0.78, 1),
	"selectedColor": Color(0.96, 0.96, 0.96, 1),
	"disabledColor": Color(0.78, 0.78, 0.78, 0.5),
	"colorMultiplier": 1.0,
	"fadeDuration": 0.1,
}
var spriteState := {}
var targetGraphic
var _hover := false
var _press := false
var _selected := false
var _normal_sprite: USprite

var interactable: bool:
	get:
		return _interactable
	set(v):
		if _interactable == v:
			return
		_interactable = v
		if not v and ES.currentSelectedGameObject == gameObject:
			ES.set_selected(null)
		_update_state(false)

var colors: Dictionary:
	get:
		return _colors.duplicate()
	set(v):
		_colors = v.duplicate()
		_update_state(true)

var image:
	get:
		return targetGraphic if targetGraphic is UImage else null
	set(v):
		targetGraphic = v

func _on_injected(root: Node) -> void:
	if u.has("m_Interactable"):
		_interactable = int(u["m_Interactable"]) != 0
	transition = int(u.get("m_Transition", 1))
	var cb = u.get("m_Colors")
	if cb is Dictionary:
		for k in ["m_NormalColor", "m_HighlightedColor", "m_PressedColor", "m_SelectedColor", "m_DisabledColor"]:
			if cb.has(k):
				var c = DB.conv(cb[k], root)
				var name_k: String = k.substr(2, 1).to_lower() + k.substr(3)
				_colors[name_k] = c
		_colors["colorMultiplier"] = float(cb.get("m_ColorMultiplier", 1.0))
		_colors["fadeDuration"] = float(cb.get("m_FadeDuration", 0.1))
	var ss = u.get("m_SpriteState")
	if ss is Dictionary:
		spriteState = {
			"highlightedSprite": DB.conv(ss.get("m_HighlightedSprite"), root),
			"pressedSprite": DB.conv(ss.get("m_PressedSprite"), root),
			"selectedSprite": DB.conv(ss.get("m_SelectedSprite"), root),
			"disabledSprite": DB.conv(ss.get("m_DisabledSprite"), root),
		}
	targetGraphic = DB.conv(u.get("m_TargetGraphic"), root)
	if targetGraphic is UImage:
		_normal_sprite = targetGraphic.sprite
	_selectable_injected(root)

func _selectable_injected(_root: Node) -> void:
	pass

func IsInteractable() -> bool:
	if not _interactable:
		return false
	var go = gameObject
	while go != null:
		for c in go.get_children():
			if c is UCanvasGroup and c.enabled:
				if not c.interactable:
					return false
				if c.ignoreParentGroups:
					return true
		go = U.parent(go)
	return true

func IsActive() -> bool:
	return _active

func OnEnable() -> void:
	_update_state(true)

func OnDisable() -> void:
	_hover = false
	_press = false
	_selected = false
	_apply(0, true)

func OnPointerEnter(_e) -> void:
	_hover = true
	_update_state(false)

func OnPointerExit(_e) -> void:
	_hover = false
	_update_state(false)

func OnPointerDown(e) -> void:
	if e.button != 0:
		return
	if IsInteractable():
		ES.set_selected(gameObject)
	_press = true
	_update_state(false)

func OnPointerUp(e) -> void:
	if e.button != 0:
		return
	_press = false
	_update_state(false)

func OnSelect(_e) -> void:
	_selected = true
	_update_state(false)

func OnDeselect(_e) -> void:
	_selected = false
	_update_state(false)

func Select() -> void:
	ES.set_selected(gameObject)

func current_state() -> int:
	if not IsInteractable():
		return 4
	if _press:
		return 2
	if _selected:
		return 3
	if _hover:
		return 1
	return 0

func _update_state(instant: bool) -> void:
	if not _active and not instant:
		return
	_apply(current_state(), instant)

func _apply(state: int, instant: bool) -> void:
	var tg = targetGraphic
	if tg == null or not is_instance_valid(tg):
		return
	match transition:
		1:
			var key: String = ["normalColor", "highlightedColor", "pressedColor", "selectedColor", "disabledColor"][state]
			var c: Color = _colors.get(key, Color.WHITE) * float(_colors.get("colorMultiplier", 1.0))
			if tg.has_method("CrossFadeColor"):
				tg.CrossFadeColor(c, 0.0 if instant else float(_colors.get("fadeDuration", 0.1)), true, true)
		2:
			if tg is UImage:
				var sp = null
				match state:
					1:
						sp = spriteState.get("highlightedSprite")
					2:
						sp = spriteState.get("pressedSprite")
					3:
						sp = spriteState.get("selectedSprite")
					4:
						sp = spriteState.get("disabledSprite")
				tg.sprite = sp if sp != null else _normal_sprite
