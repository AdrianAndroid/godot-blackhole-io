class_name AttractionBurst
extends Node3D

const DURATION: float = 0.32

var target: HoleActor
var age: float = 0.0
var start_position := Vector3.ZERO
var trail_color := Color("0757f6")
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var immediate_mesh: ImmediateMesh
var mesh_revision: int = 0


func prepare() -> void:
	if mesh_instance != null:
		return
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "AttractionTrails"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	immediate_mesh = ImmediateMesh.new()
	mesh_instance.mesh = immediate_mesh
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.7
	mesh_instance.material_override = material
	add_child(mesh_instance)
	visible = false


func setup(start_value: Vector3, hole: HoleActor, color: Color) -> void:
	prepare()
	start_position = start_value
	target = hole
	trail_color = color
	age = 0.0
	visible = true
	material.albedo_color = Color(color.lightened(0.4), 0.75)
	material.emission = color
	_rebuild_trails()


func step(delta: float) -> void:
	age += delta
	if is_instance_valid(target):
		_rebuild_trails()
	if material != null:
		material.albedo_color.a = (1.0 - age / DURATION) * 0.75


func finished() -> bool:
	return age >= DURATION or not is_instance_valid(target)


func release() -> void:
	target = null
	age = 0.0
	visible = false
	if immediate_mesh != null:
		immediate_mesh.clear_surfaces()


func _rebuild_trails() -> void:
	if mesh_instance == null or not is_instance_valid(target):
		return
	var end := target.global_position + Vector3(0, 0.18, 0)
	immediate_mesh.clear_surfaces()
	mesh_revision += 1
	for lane in 3:
		immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for index in 13:
			var t := float(index) / 12.0
			var point := start_position.lerp(end, t)
			point.y += 0.025 + sin(t * PI) * (0.16 + lane * 0.055)
			immediate_mesh.surface_add_vertex(point)
		immediate_mesh.surface_end()
