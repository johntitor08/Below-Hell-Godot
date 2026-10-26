class_name PlayerInput
extends RefCounted

var prefix := ""

func _init(p := "") -> void:
	prefix = p

func poll(_c: Creature, i: CreatureInput) -> void:
	i.move = Vector2(Input.get_axis(prefix + "left", prefix + "right"), Input.get_axis(prefix + "up", prefix + "down"))
	i.jump = i.jump or Input.is_action_just_pressed(prefix + "jump")
	i.jump_held = Input.is_action_pressed(prefix + "jump")
	i.attack = i.attack or Input.is_action_just_pressed(prefix + "attack")
	i.ability = i.ability or Input.is_action_just_pressed(prefix + "ability")
	i.ability_held = Input.is_action_pressed(prefix + "ability")
	i.ability2 = i.ability2 or Input.is_action_just_pressed(prefix + "ability2")
