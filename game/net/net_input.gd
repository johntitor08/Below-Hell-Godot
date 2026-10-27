class_name NetRemoteInput
extends RefCounted

var latest := CreatureInput.new()
var _edges := {"jump": false, "attack": false, "ability": false, "ability2": false}

func _init() -> void:
	Net.remote_input.connect(_on_input)

func _on_input(arr: Array) -> void:
	var i := CreatureInput.from_array(arr)
	latest.move = i.move
	latest.jump_held = i.jump_held
	latest.ability_held = i.ability_held
	_edges.jump = _edges.jump or i.jump
	_edges.attack = _edges.attack or i.attack
	_edges.ability = _edges.ability or i.ability
	_edges.ability2 = _edges.ability2 or i.ability2

func poll(_c, i: CreatureInput) -> void:
	i.move = latest.move
	i.jump_held = latest.jump_held
	i.ability_held = latest.ability_held
	i.jump = i.jump or _edges.jump
	i.attack = i.attack or _edges.attack
	i.ability = i.ability or _edges.ability
	i.ability2 = i.ability2 or _edges.ability2
	for k in _edges:
		_edges[k] = false
