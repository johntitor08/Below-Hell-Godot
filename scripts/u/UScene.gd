class_name UScene
extends Node

static var OnSceneBooted := UEvent.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	DB.ensure_loaded()
	var additive := get_tree().current_scene != null and get_tree().current_scene != self
	if not additive:
		ES.reset()
	boot_subtree(self, self, false)
	if not additive:
		OnSceneBooted.Invoke(self)

static func boot_subtree(root: Node, owner_root: Node, _is_dup: bool) -> void:
	var monos := []
	U.monos_in(root, monos)
	for m in monos:
		m._inject(owner_root)
	var on := true
	if root is CanvasItem:
		on = U.activeInHierarchy(root)
	U._refresh(root, on)
	ES.mark_layout_dirty()
