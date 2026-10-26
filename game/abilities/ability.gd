class_name Ability
extends Node

var creature: Creature
var id := ""
var slot := 0
var cooldown := 0.0
var _cd := 0.0

func on_added() -> void:
	pass

func on_removed() -> void:
	pass

func physics(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	var trig := false
	if slot == 1:
		trig = creature.input.ability
	elif slot == 2:
		trig = creature.input.ability2
	if trig and _cd <= 0.0 and creature.alive and creature.controls_enabled:
		if activate():
			_cd = cooldown
	tick(delta)

func activate() -> bool:
	return false

func tick(_delta: float) -> void:
	pass

func modify_incoming(dmg: int, _source) -> int:
	return dmg

func prevent_death() -> bool:
	return false

func on_hurt(_dmg: int, _source) -> void:
	pass

func ready_ratio() -> float:
	return 1.0 if cooldown <= 0.0 else 1.0 - _cd / cooldown

func world() -> Node:
	var s := creature.get_tree().current_scene
	var w = s.get_node_or_null("World")
	return w if w != null else s

func foes_in_radius(p: Vector2, r: float) -> Array:
	var out := []
	for n in creature.get_tree().get_nodes_in_group("enemies") + creature.get_tree().get_nodes_in_group("creatures"):
		if n == creature or not is_instance_valid(n):
			continue
		if n is Creature and (n.team == creature.team or not n.alive):
			continue
		if n.has_method("center") and n.center().distance_to(p) <= r:
			out.append(n)
		elif n is Node2D and n.global_position.distance_to(p) <= r:
			out.append(n)
	return out

func breakables_in_radius(p: Vector2, r: float) -> Array:
	var out := []
	for n in creature.get_tree().get_nodes_in_group("breakable"):
		if is_instance_valid(n) and n.global_position.distance_to(p) <= r + 32.0:
			out.append(n)
	return out

func hit(target, dmg: int, knock := Vector2(400, -300)) -> void:
	if target.has_method("take_hit"):
		var k := Vector2(signf(target.global_position.x - creature.global_position.x) * absf(knock.x), knock.y)
		target.take_hit(dmg, creature.global_position, k, creature)
		creature.hit_landed.emit(target, dmg)
