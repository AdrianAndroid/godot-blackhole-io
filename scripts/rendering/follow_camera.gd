class_name FollowCamera
extends Node3D

var perspective_camera: Camera3D
var orthographic_camera: Camera3D
var projection: String = "perspective"
var map_size := Vector2(96, 96)
var base_offset := Vector3(7, 14.5, 11)
var base_orthographic_size: float = 12.0
var zoom: float = 1.0
var smoothing: float = 10.0
var zoom_smoothing: float = 7.0
var initialized: bool = false
var shake_strength: float = 0.0
var visual_time: float = 0.0
var shake_offset := Vector3.ZERO
var finale_active: bool = false
var finale_blend: float = 0.0


func _ready() -> void:
	perspective_camera = Camera3D.new()
	perspective_camera.name = "Perspective"
	perspective_camera.fov = 32.0
	perspective_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	perspective_camera.near = 0.1
	perspective_camera.far = 250.0
	add_child(perspective_camera)
	orthographic_camera = Camera3D.new()
	orthographic_camera.name = "Orthographic"
	orthographic_camera.near = 0.1
	orthographic_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	orthographic_camera.far = 250.0
	add_child(orthographic_camera)
	set_projection(projection)
	_update_camera_transform()


func set_projection(mode: String) -> bool:
	if mode not in ["perspective", "orthographic"]:
		return false
	projection = mode
	if perspective_camera != null:
		perspective_camera.current = mode == "perspective"
		orthographic_camera.current = mode == "orthographic"
	return true


func step(delta: float, target_position: Vector3, radius: float) -> void:
	var desired := Vector3(target_position.x, 0, target_position.z)
	finale_blend = move_toward(finale_blend, 1.0 if finale_active else 0.0, delta * 1.25)
	var target_zoom := growth_zoom(radius) * lerpf(1.0, 1.55, finale_blend)
	if not initialized:
		position = desired
		zoom = target_zoom
		initialized = true
	else:
		position = position.lerp(desired, 1.0 - exp(-smoothing * delta))
		zoom = lerpf(zoom, target_zoom, 1.0 - exp(-zoom_smoothing * delta))
	_clamp_to_map(desired)
	visual_time += delta
	shake_strength = move_toward(shake_strength, 0.0, delta * 0.65)
	shake_offset = Vector3(sin(visual_time * 71.0), cos(visual_time * 83.0) * 0.35, cos(visual_time * 59.0)) * shake_strength
	_update_camera_transform()


func snap(target_position: Vector3, radius: float) -> void:
	position = Vector3(target_position.x, 0, target_position.z)
	zoom = growth_zoom(radius) * lerpf(1.0, 1.55, finale_blend)
	initialized = true
	shake_offset = Vector3.ZERO
	_clamp_to_map(Vector3(target_position.x, 0, target_position.z))
	_update_camera_transform()


func _clamp_to_map(target_position: Vector3) -> void:
	var margin := Vector2(7.0, 9.0) * zoom
	var half := map_size * 0.5
	var unclamped := position
	position.x = clampf(position.x, -half.x + margin.x, half.x - margin.x)
	position.z = clampf(position.z, -half.y + margin.y, half.y - margin.y)
	# At a playable map edge, retaining the hole is more important than hiding
	# the void beyond the ground. Out-of-map test targets remain map-clamped.
	if not is_equal_approx(unclamped.x, position.x) and absf(target_position.x) <= half.x:
		position.x = clampf(position.x, target_position.x - 0.5 * zoom, target_position.x + 0.5 * zoom)
	if not is_equal_approx(unclamped.z, position.z) and absf(target_position.z) <= half.y:
		position.z = clampf(position.z, target_position.z - 0.75 * zoom, target_position.z + 0.75 * zoom)


func growth_zoom(radius: float) -> float:
	# Let early growth occupy more of the frame; preserve the established max-level view.
	return 1.0 + maxf(0.0, radius - 1.0) * 0.5775


func screen_to_ground(screen_input: Vector2) -> Vector2:
	var camera_yaw := atan2(base_offset.x, base_offset.z)
	return screen_input.rotated(-camera_yaw)


func set_finale(active: bool) -> void:
	finale_active = active


func add_shake(strength: float) -> void:
	shake_strength = maxf(shake_strength, clampf(strength, 0.0, 0.24))


func _update_camera_transform() -> void:
	if perspective_camera == null:
		return
	var offset := base_offset * zoom + shake_offset
	perspective_camera.position = offset
	orthographic_camera.position = offset
	orthographic_camera.size = base_orthographic_size * zoom
	if is_inside_tree():
		perspective_camera.look_at(global_position)
		orthographic_camera.look_at(global_position)
	else:
		perspective_camera.rotation = Basis.looking_at(-offset.normalized(), Vector3.UP).get_euler()
		orthographic_camera.rotation = perspective_camera.rotation


func snapshot() -> Dictionary:
	return {
		"projection": projection,
		"position": [position.x, position.y, position.z],
		"zoom": zoom,
		"perspective_transform": str(perspective_camera.transform) if perspective_camera != null else "",
		"orthographic_transform": str(orthographic_camera.transform) if orthographic_camera != null else ""
	}
