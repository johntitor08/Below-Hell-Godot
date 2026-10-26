class_name CreatureInput
extends RefCounted

var move := Vector2.ZERO
var jump := false
var jump_held := false
var attack := false
var ability := false
var ability_held := false
var ability2 := false
var drop := false

func clear_edges() -> void:
	jump = false
	attack = false
	ability = false
	ability2 = false
	drop = false

func to_array() -> Array:
	return [move.x, move.y, jump, jump_held, attack, ability, ability_held, ability2]

static func from_array(a: Array) -> CreatureInput:
	var i := CreatureInput.new()
	if a.size() >= 8:
		i.move = Vector2(float(a[0]), float(a[1]))
		i.jump = bool(a[2])
		i.jump_held = bool(a[3])
		i.attack = bool(a[4])
		i.ability = bool(a[5])
		i.ability_held = bool(a[6])
		i.ability2 = bool(a[7])
	return i
