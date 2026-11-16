class_name HoleActor
extends Node3D

var effective_radius: float = 0.38:
	set(value):
		var next := maxf(value, 0.01)
		if is_equal_approx(effective_radius, next):
			return
		effective_radius = next
		radius_revision += 1
		if visual != null:
			visual.effective_radius = next
		_update_area_radius()
var radius_revision: int = 0
var move_speed: float = 5.2
var map_size := Vector2(96, 96)
var faction_color := Color("3298ff"):
	set(value):
		faction_color = value
		if visual != null:
			visual.faction_color = value
var visual: HoleVisual
var detection_area: Area3D
var detection_shape: SphereShape3D
var alive: bool = true


func _ready() -> void:
	build()


func build() -> void:
	if visual != null:
		return
	visual = HoleVisual.new()
	visual.effective_radius = effective_radius
	visual.faction_color = faction_color
	add_child(visual)
	detection_area = Area3D.new()
	detection_area.name = "SwallowBroadPhase"
	var collision := CollisionShape3D.new()
	detection_shape = SphereShape3D.new()
	detection_shape.radius = effective_radius
	collision.shape = detection_shape
	detection_area.add_child(collision)
	add_child(detection_area)


func current_move_speed() -> float:
	# Match the camera's growth curve so a larger hole keeps its screen-space pace.
	return move_speed * (1.0 + maxf(0.0, effective_radius - 0.38) * 0.5)


func step(delta: float, direction: Vector2) -> void:
	if not alive:
		return
	var limited_direction := direction.limit_length(1.0)
	var motion := Vector3(limited_direction.x, 0, limited_direction.y) * current_move_speed() * delta
	var next := position + motion
	var limit := map_size * 0.5 - Vector2.ONE * effective_radius
	next.x = clampf(next.x, -maxf(0, limit.x), maxf(0, limit.x))
	next.z = clampf(next.z, -maxf(0, limit.y), maxf(0, limit.y))
	next.y = position.y
	position = next


func _update_area_radius() -> void:
	if detection_shape != null:
		detection_shape.radius = effective_radius
