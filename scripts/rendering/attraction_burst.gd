class_name AttractionBurst
extends Node3D

const DURATION: float = 0.32

var target: HoleActor
var age: float = 0.0
var start_position := Vector3.ZERO
var trail_color := Color("3298ff")
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D


func setup(start_value: Vector3, hole: HoleActor, color: Color) -> void:
	start_position = start_value
	target = hole
	trail_color = color
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "AttractionTrails"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.lightened(0.4), 0.75)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.7
	mesh_instance.material_override = material
	add_child(mesh_instance)
	_rebuild_trails()


func step(delta: float) -> void:
	age += delta
	if is_instance_valid(target):
		_rebuild_trails()
	if material != null:
		material.albedo_color.a = (1.0 - age / DURATION) * 0.75


func finished() -> bool:
	return age >= DURATION or not is_instance_valid(target)


func _rebuild_trails() -> void:
	if mesh_instance == null or not is_instance_valid(target):
		return
	var end := target.global_position + Vector3(0, 0.10, 0)
	var immediate := ImmediateMesh.new()
	for lane in 3:
		immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for index in 13:
			var t := float(index) / 12.0
			var point := start_position.lerp(end, t)
			point.y += sin(t * PI) * (0.20 + lane * 0.055)
			immediate.surface_add_vertex(point)
		immediate.surface_end()
	mesh_instance.mesh = immediate
