class_name UToggleGroup
extends Mono

var allowSwitchOff := false
var toggles: Array = []

func _on_injected(_root: Node) -> void:
	allowSwitchOff = int(u.get("m_AllowSwitchOff", 0)) != 0

func RegisterToggle(t) -> void:
	if not toggles.has(t):
		toggles.append(t)

func UnregisterToggle(t) -> void:
	toggles.erase(t)

func NotifyToggleOn(t, notify := true) -> void:
	for o in toggles:
		if o == t or not is_instance_valid(o):
			continue
		if notify:
			o.isOn = false
		else:
			o.SetIsOnWithoutNotify(false)

func AnyTogglesOn() -> bool:
	for o in toggles:
		if is_instance_valid(o) and o.isOn:
			return true
	return false

func SetAllTogglesOff(notify := true) -> void:
	var old := allowSwitchOff
	allowSwitchOff = true
	for o in toggles:
		if not is_instance_valid(o):
			continue
		if notify:
			o.isOn = false
		else:
			o.SetIsOnWithoutNotify(false)
	allowSwitchOff = old
