class_name UEffector2D
extends Mono

var kind := ""
var useOneWay := true
var surfaceArc := 180.0
var density := 1.0
var surfaceLevel := 0.0
var linearDrag := 1.0
var flowMagnitude := 0.0
var _area: Area2D

func _on_injected(_root: Node) -> void:
	kind = str(u.get("$type", ""))
	useOneWay = int(u.get("m_UseOneWay", 1)) != 0
	surfaceArc = float(u.get("m_SurfaceArc", 180))
	density = float(u.get("m_Density", 2))
	surfaceLevel = float(u.get("m_SurfaceLevel", 0))
	linearDrag = float(u.get("m_LinearDrag", 1))
	flowMagnitude = float(u.get("m_FlowMagnitude", 0))

func is_platform() -> bool:
	return kind == "PlatformEffector2D" and useOneWay

func FixedUpdate() -> void:
	if kind != "BuoyancyEffector2D":
		return
	var go = gameObject
	if not (go is Area2D):
		var b = go
		for c in go.get_children():
			if c is Area2D and c.has_meta("trigger_owner"):
				b = c
		if not (b is Area2D):
			return
		go = b
	var surface_y := U.pos(gameObject).y + surfaceLevel
	for body in go.get_overlapping_bodies():
		if body is URigidbody2D and body.bodyType == 0:
			var depth: float = surface_y - body.rbPosition.y
			if depth > 0.0:
				var g: float = UPhys.gravity.length() * body.gravityScale
				var lift: float = density * g * minf(depth, 1.0) * body.mass * 0.5
				body.AddForce(Vector2(flowMagnitude, lift), 0)
				body.velocity = body.velocity * maxf(0.0, 1.0 - linearDrag * get_physics_process_delta_time())
