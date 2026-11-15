class_name HoleVisual
extends Node3D

var effective_radius: float = 0.38:
	set(value):
		effective_radius = maxf(value, 0.01)
		_update_size()
var faction_color: Color = Color("3298ff"):
	set(value):
		faction_color = value
		_update_color()
var disk: MeshInstance3D
var hole_material: ShaderMaterial
var animation_time: float = -1.0:
	set(value):
		animation_time = value
		if hole_material != null:
			hole_material.set_shader_parameter("animation_time", value)


func _ready() -> void:
	build()


func build() -> void:
	if disk != null:
		return
	disk = MeshInstance3D.new()
	disk.name = "GroundHole"
	var plane := PlaneMesh.new()
	disk.mesh = plane
	disk.position.y = 0.055
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole_material = ShaderMaterial.new()
	hole_material.shader = load("res://assets/game/shaders/black_hole.gdshader")
	disk.material_override = hole_material
	add_child(disk)
	_update_size()
	_update_color()
	hole_material.set_shader_parameter("animation_time", animation_time)


func visual_diameter() -> float:
	return effective_radius * 2.0


func _update_size() -> void:
	if disk != null:
		(disk.mesh as PlaneMesh).size = Vector2.ONE * visual_diameter()


func _update_color() -> void:
	if hole_material != null:
		hole_material.set_shader_parameter("faction_color", faction_color)
