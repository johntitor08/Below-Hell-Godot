@tool
extends Node

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	U.run_late()
	if ES._layout_dirty:
		ES.rebuild_layout()
