class_name UToggle
extends USelectable

var _isOn := false
var toggleTransition := 1
var graphic
var group
var onValueChanged := UEvent.new()

var isOn: bool:
	get:
		return _isOn
	set(v):
		Set(v, true)

func _selectable_injected(root: Node) -> void:
	_isOn = int(u.get("m_IsOn", 0)) != 0
	toggleTransition = int(u.get("toggleTransition", 1))
	graphic = DB.conv(u.get("graphic"), root)
	group = DB.conv(u.get("m_Group"), root)
	var e = DB.conv(u.get("onValueChanged"), root)
	if e is UEvent:
		onValueChanged = e

func Awake() -> void:
	if group != null and group.has_method("RegisterToggle"):
		group.RegisterToggle(self)

func OnEnable() -> void:
	super.OnEnable()
	_play_effect(true)
	if group != null and group.has_method("RegisterToggle"):
		group.RegisterToggle(self)
		if _isOn:
			group.NotifyToggleOn(self, false)

func SetIsOnWithoutNotify(v: bool) -> void:
	Set(v, false)

func Set(v: bool, notify: bool) -> void:
	if _isOn == v:
		return
	_isOn = v
	if group != null and is_instance_valid(group) and _active:
		if _isOn or (not group.AnyTogglesOn() and not group.allowSwitchOff):
			_isOn = true
			group.NotifyToggleOn(self, notify)
	_play_effect(toggleTransition == 0)
	if notify:
		onValueChanged.Invoke(_isOn)

func _play_effect(instant: bool) -> void:
	if graphic == null or not is_instance_valid(graphic):
		return
	if graphic.has_method("CrossFadeAlpha"):
		graphic.CrossFadeAlpha(1.0 if _isOn else 0.0, 0.0 if instant else 0.1, true)

func OnPointerClick(e) -> void:
	if e.button != 0:
		return
	_internal_toggle()

func OnSubmit(_e) -> void:
	_internal_toggle()

func _internal_toggle() -> void:
	if not _active or not IsInteractable():
		return
	isOn = not _isOn
