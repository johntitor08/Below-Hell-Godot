class_name Projectile
extends Area2D

var velocity := Vector2.ZERO
var grav := 0.0
var damage := 10
var team := 1
var life := 4.0
var color := Color(1, 0.5, 0.3)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2 | 128
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 14.0
	cs.shape = c
	add_child(cs)
	var s := Sprite2D.new()
	s.texture = Fx.soft_tex
	s.modulate = color
	s.scale = Vector2(0.5, 0.5)
	add_child(s)
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	velocity.y += grav * delta
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body(b: Node) -> void:
	if b is Creature:
		if b.team == team:
			return
		b.take_hit(damage, global_position, Vector2(signf(velocity.x) * 400.0, -300.0), self)
	Fx.burst(global_position, "hit", color, 10)
	queue_free()
