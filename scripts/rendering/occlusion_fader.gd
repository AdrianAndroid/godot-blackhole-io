class_name OcclusionFader
extends RefCounted

const FADED_ALPHA: float = 0.22
const FADE_SPEED: float = 5.0
var states: Dictionary = {}
var material_writes: int = 0


func register(objects: Array) -> void:
	for object in objects:
		if not object is Swallowable or object.kind != "normal":
			continue
		if object.footprint_radius < 1.0:
			continue
		var records: Array[Dictionary] = []
		_collect_materials(object.model_root, records)
		if not records.is_empty():
			states[object.get_instance_id()] = {"object": object, "amount": 0.0, "records": records}


func step(delta: float, hole_position: Vector3, hole_radius: float, camera: Camera3D = null) -> void:
	for id in states.keys():
		var state: Dictionary = states[id]
		var object: Swallowable = state.object
		if not is_instance_valid(object):
			states.erase(id)
			continue
		var distance := Vector2(object.position.x - hole_position.x, object.position.z - hole_position.z).length()
		var blocked := object.state != Swallowable.State.SETTLED and object.footprint_radius >= hole_radius
		var covers_hole := distance < object.footprint_radius + hole_radius * 0.4
		blocked = blocked and (covers_hole or _blocks_view(object, hole_position, hole_radius, camera))
		var next := move_toward(float(state.amount), 1.0 if blocked else 0.0, delta * FADE_SPEED)
		if is_equal_approx(float(state.amount), next):
			continue
		state.amount = next
		_apply(state)


func _blocks_view(object: Swallowable, hole_position: Vector3, hole_radius: float, camera: Camera3D) -> bool:
	if camera == null:
		return false
	var camera_ground := Vector2(camera.global_position.x, camera.global_position.z)
	var hole_ground := Vector2(hole_position.x, hole_position.z)
	var view_segment := hole_ground - camera_ground
	var length_squared := view_segment.length_squared()
	if length_squared < 0.001:
		return false
	var object_ground := Vector2(object.position.x, object.position.z)
	var along := (object_ground - camera_ground).dot(view_segment) / length_squared
	if along <= 0.0 or along >= 1.0:
		return false
	var nearest := camera_ground + view_segment * along
	return object_ground.distance_to(nearest) < object.footprint_radius + maxf(0.35, hole_radius * 0.4)


func fade_amount(object: Swallowable) -> float:
	return float(states.get(object.get_instance_id(), {}).get("amount", 0.0))


func reset() -> void:
	for state in states.values():
		if is_zero_approx(float(state.amount)):
			continue
		state.amount = 0.0
		_apply(state)


func unregister(object: Swallowable) -> void:
	states.erase(object.get_instance_id())


func _collect_materials(node: Node, records: Array[Dictionary]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var source: Material = node.get_active_material(surface)
			if not source is StandardMaterial3D:
				continue
			var material := source.duplicate() as StandardMaterial3D
			node.set_surface_override_material(surface, material)
			records.append({
				"mesh": node,
				"material": material,
				"color": material.albedo_color,
				"transparency": material.transparency,
				"shadow": node.cast_shadow,
			})
	for child in node.get_children():
		_collect_materials(child, records)


func _apply(state: Dictionary) -> void:
	var amount := float(state.amount)
	for record in state.records:
		if not is_instance_valid(record.mesh):
			continue
		var material := record.material as StandardMaterial3D
		var color := record.color as Color
		color.a *= lerpf(1.0, FADED_ALPHA, amount)
		material.albedo_color = color
		material_writes += 1
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if amount > 0.001 else int(record.transparency)
		record.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if amount > 0.05 else int(record.shadow)
