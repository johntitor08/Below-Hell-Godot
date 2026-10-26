class_name UButton
extends USelectable

var onClick := UEvent.new()

func _selectable_injected(root: Node) -> void:
	var e = DB.conv(u.get("m_OnClick"), root)
	if e is UEvent:
		onClick = e

func OnPointerClick(e) -> void:
	if e.button != 0:
		return
	Press()

func OnSubmit(_e) -> void:
	Press()

func Press() -> void:
	if not _active or not IsInteractable():
		return
	onClick.Invoke()
