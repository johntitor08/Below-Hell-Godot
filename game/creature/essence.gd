class_name Essence
extends Node

signal changed(oz: int, cap: int)
signal form_changed(def: CreatureDef)
signal message(text: String, color: Color)

var creature: Creature
var oz := 0
var cap := 6
var stack: Array[CreatureDef] = []
var spent: Array[int] = []

func setup(c: Creature, start_oz: int, start_cap: int) -> void:
	creature = c
	oz = start_oz
	cap = start_cap
	stack = [Creatures.fallback()]
	spent = [0]
	creature.set_form(stack[0])
	creature.died.connect(_on_died)
	changed.emit(oz, cap)

func current() -> CreatureDef:
	return stack[stack.size() - 1]

func add(n: int) -> bool:
	if oz >= cap:
		message.emit(Game.t("cap_full"), Color(1, 0.8, 0.4))
		return false
	oz = mini(cap, oz + n)
	changed.emit(oz, cap)
	return true

func can_afford(d: CreatureDef) -> bool:
	return d == Creatures.fallback() or oz >= d.oz_cost

func transform_to(d: CreatureDef) -> bool:
	if d == current():
		return false
	if d == Creatures.fallback():
		while stack.size() > 1:
			_pop(true)
		_apply()
		return true
	if oz < d.oz_cost:
		message.emit(Game.t("need_oz"), Color(1, 0.5, 0.45))
		return false
	if not _fits(d):
		message.emit("✕", Color(1, 0.5, 0.45))
		return false
	oz -= d.oz_cost
	stack.append(d)
	spent.append(d.oz_cost)
	Game.mark_seen(d.id)
	_apply()
	changed.emit(oz, cap)
	return true

func revert() -> bool:
	if stack.size() <= 1:
		return false
	_pop(true)
	_apply()
	changed.emit(oz, cap)
	return true

func _pop(refund: bool) -> void:
	var s: int = spent.pop_back()
	stack.pop_back()
	if refund:
		oz = mini(cap, oz + int(floor(s * Creatures.revert_refund())))

func _fits(d: CreatureDef) -> bool:
	var h := d.height_px() * (0.6 if d.flight else 0.74)
	var w := h
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w * 0.8, h)
	q.shape = r
	q.transform = Transform2D(0, creature.global_position + Vector2(0, -h * 0.5 - 2))
	q.collision_mask = 1 | 128
	q.exclude = [creature.get_rid()]
	return creature.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()

func _apply() -> void:
	var d := current()
	creature.set_form(d, true)
	Fx.burst(creature.center(), "transform", d.accent)
	Fx.shake(6.0, 0.2)
	Audio.play("spawn", -2.0)
	form_changed.emit(d)

func _on_died(_c) -> void:
	if stack.size() > 1:
		_pop(false)
	changed.emit(oz, cap)
