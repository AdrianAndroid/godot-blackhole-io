class_name OcclusionFader
extends RefCounted

const FADED_ALPHA: float = 0.22
const FADE_SPEED: float = 5.0
var states: Dictionary = {}


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


func step(delta: float, hole_position: Vector3, hole_radius: float) -> void:
	for id in states.keys():
		var state: Dictionary = states[id]
		var object: Swallowable = state.object
		if not is_instance_valid(object):
			states.erase(id)
			continue
		var distance := Vector2(object.position.x - hole_position.x, object.position.z - hole_position.z).length()
		var blocked := object.state != Swallowable.State.SETTLED and object.footprint_radius >= hole_radius
		blocked = blocked and distance < object.footprint_radius + hole_radius * 0.4
		state.amount = move_toward(float(state.amount), 1.0 if blocked else 0.0, delta * FADE_SPEED)
		_apply(state)


func fade_amount(object: Swallowable) -> float:
	return float(states.get(object.get_instance_id(), {}).get("amount", 0.0))


func reset() -> void:
	for state in states.values():
		state.amount = 0.0
		_apply(state)


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
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if amount > 0.001 else int(record.transparency)
		record.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if amount > 0.05 else int(record.shadow)
