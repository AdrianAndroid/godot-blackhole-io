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


func capture_transform() -> void:
	_origin = position
	_initial_scale = scale
	_initial_rotation = rotation


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
