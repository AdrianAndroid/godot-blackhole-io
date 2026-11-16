class_name Swallowable
extends Node3D

enum State { IDLE, CLAIMED, SINKING, SETTLED }

var object_id: int = 0
var model_id: String = ""
var kind: String = "normal"
var footprint_radius: float = 0.2
var xp: int = 0
var score: int = 0
var coins: int = 0
var state: State = State.IDLE
var claimed_by: int = -1
var progress: float = 0.0
var sink_duration: float = 0.55
var model_root: Node3D
var area: Area3D
var _origin := Vector3.ZERO
var _initial_scale := Vector3.ONE
var _initial_rotation := Vector3.ZERO
var motion_route := PackedVector3Array()
var motion_speed: float = 0.0
var route_distance: float = 0.0
var _route_length: float = 0.0
var _route_segment_lengths: Array[float] = []
var _animation_player: AnimationPlayer


func setup(entry: Dictionary, stable_id: int, model: Node3D) -> void:
	object_id = stable_id
	model_id = entry.get("id", "")
	footprint_radius = float(entry.get("footprint_radius", 0.2))
	xp = int(entry.get("xp", 0))
	score = int(entry.get("score", 0))
	coins = int(entry.get("coins", 0))
	model_root = model
	add_child(model_root)
	_origin = position
	_initial_scale = scale
	_initial_rotation = rotation
	area = Area3D.new()
	area.name = "BroadPhase"
	area.monitoring = false
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = footprint_radius
	collision.shape = sphere
	area.add_child(collision)
	add_child(area)
	set_meta("object_id", object_id)
	_animation_player = _find_animation_player(model_root)


func configure_route(points: PackedVector3Array, speed: float, phase: float = 0.0) -> void:
	motion_route = points
	motion_speed = speed
	_route_segment_lengths.clear()
	_route_length = 0.0
	for index in motion_route.size():
		var length := motion_route[index].distance_to(motion_route[(index + 1) % motion_route.size()])
		_route_segment_lengths.append(length)
		_route_length += length
	route_distance = fposmod(phase, _route_length) if _route_length > 0.0 else 0.0
	advance_route(0.0)


func capture_transform() -> void:
	_origin = position
	_initial_scale = scale
	_initial_rotation = rotation


func advance_route(delta: float) -> void:
	if state != State.IDLE or motion_route.size() < 2 or _route_length <= 0.0:
		return
	route_distance = fposmod(route_distance + motion_speed * delta, _route_length)
	var remaining := route_distance
	for index in motion_route.size():
		var segment_length := _route_segment_lengths[index]
		if remaining <= segment_length or index == motion_route.size() - 1:
			var start := motion_route[index]
			var end := motion_route[(index + 1) % motion_route.size()]
			var direction := (end - start).normalized()
			position = start.lerp(end, clampf(remaining / segment_length, 0.0, 1.0))
			if not direction.is_zero_approx():
				rotation.y = atan2(-direction.x, -direction.z)
			break
		remaining -= segment_length
	if _animation_player != null:
		_animation_player.advance(delta)
	if model_id == "duck":
		model_root.position.y = 0.03 + sin(route_distance * 3.0) * 0.035


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func claim(owner_id: int) -> bool:
	if state != State.IDLE:
		return false
	claimed_by = owner_id
	state = State.CLAIMED
	capture_transform()
	return true


func begin_sinking() -> void:
	if state == State.CLAIMED:
		state = State.SINKING


func advance(delta: float, hole_position: Vector3) -> bool:
	if state != State.SINKING:
		return false
	progress = minf(1.0, progress + delta / sink_duration)
	var eased := smoothstep(0.0, 1.0, progress)
	position.x = lerpf(_origin.x, hole_position.x, eased)
	position.z = lerpf(_origin.z, hole_position.z, eased)
	position.y = _origin.y - eased * maxf(1.2, footprint_radius * 1.5)
	rotation = _initial_rotation + Vector3(eased * 0.35, eased * 0.4, eased * 0.65)
	scale = _initial_scale * maxf(0.02, 1.0 - eased * 0.9)
	if progress >= 1.0:
		visible = false
		state = State.SETTLED
		return true
	return false


func cancel() -> void:
	if state == State.SETTLED:
		return
	state = State.IDLE
	claimed_by = -1
	progress = 0.0
	position = _origin
	scale = _initial_scale
	rotation = _initial_rotation
	visible = true
