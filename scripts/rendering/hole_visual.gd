class_name HoleVisual
extends Node3D

const PARTICLE_COUNT := 12

var effective_radius: float = 0.38:
	set(value):
		effective_radius = maxf(value, 0.01)
		_update_size()
var faction_color: Color = Color("3298ff"):
	set(value):
		faction_color = value
		_update_color()
var disk: MeshInstance3D
var glow: MeshInstance3D
var rim: MeshInstance3D
var hole_material: ShaderMaterial
var glow_material: ShaderMaterial
var rim_material: StandardMaterial3D
var particle_material: StandardMaterial3D
var edge_particles: Array[MeshInstance3D] = []
var feedback_pulse: float = 0.0
var animation_time: float = -1.0:
	set(value):
		animation_time = value
		if hole_material != null:
			hole_material.set_shader_parameter("animation_time", value)
		_update_particles()


func _ready() -> void:
	build()


func build() -> void:
	if disk != null:
		return
	glow = MeshInstance3D.new()
	glow.name = "GroundGlow"
	glow.mesh = PlaneMesh.new()
	glow.position.y = 0.038
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_material = ShaderMaterial.new()
	glow_material.shader = load("res://assets/game/shaders/hole_glow.gdshader")
	glow.material_override = glow_material
	add_child(glow)
	disk = MeshInstance3D.new()
	disk.name = "GroundHole"
	disk.mesh = PlaneMesh.new()
	disk.position.y = 0.055
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole_material = ShaderMaterial.new()
	hole_material.shader = load("res://assets/game/shaders/black_hole.gdshader")
	disk.material_override = hole_material
	add_child(disk)
	rim = MeshInstance3D.new()
	rim.name = "LuminousRim"
	rim.mesh = TorusMesh.new()
	(rim.mesh as TorusMesh).rings = 48
	(rim.mesh as TorusMesh).ring_segments = 12
	rim.position.y = 0.082
	rim.scale.y = 0.18
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim_material = StandardMaterial3D.new()
	rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_material.emission_enabled = true
	rim.material_override = rim_material
	add_child(rim)
	particle_material = StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.emission_enabled = true
	particle_material.emission_energy_multiplier = 0.8
	for index in PARTICLE_COUNT:
		var particle := MeshInstance3D.new()
		particle.name = "EdgeSpark_%02d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		particle.mesh = sphere
		particle.material_override = particle_material
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particle)
		edge_particles.append(particle)
	_update_size()
	_update_color()
	hole_material.set_shader_parameter("animation_time", animation_time)


func step(delta: float) -> void:
	animation_time = maxf(0.0, animation_time) + delta
	feedback_pulse = move_toward(feedback_pulse, 0.0, delta * 3.5)
	if glow_material != null:
		glow_material.set_shader_parameter("strength", 1.0 + feedback_pulse * 1.8)
	if rim != null:
		rim.scale.y = 0.18 + feedback_pulse * 0.06


func trigger_pulse(strength: float = 1.0) -> void:
	feedback_pulse = maxf(feedback_pulse, clampf(strength, 0.0, 1.0))
	if glow_material != null:
		glow_material.set_shader_parameter("strength", 1.0 + feedback_pulse * 1.8)


func visual_diameter() -> float:
	return effective_radius * 2.0


func _update_size() -> void:
	if disk == null:
		return
	(disk.mesh as PlaneMesh).size = Vector2.ONE * visual_diameter()
	(glow.mesh as PlaneMesh).size = Vector2.ONE * visual_diameter() * 1.55
	var torus := rim.mesh as TorusMesh
	torus.inner_radius = effective_radius * 0.77
	torus.outer_radius = effective_radius * 0.985
	for particle in edge_particles:
		particle.scale = Vector3.ONE * effective_radius * 0.032
	_update_particles()


func _update_color() -> void:
	if hole_material == null:
		return
	hole_material.set_shader_parameter("faction_color", faction_color)
	glow_material.set_shader_parameter("faction_color", faction_color)
	rim_material.albedo_color = faction_color.lightened(0.18)
	rim_material.emission = faction_color
	rim_material.emission_energy_multiplier = 0.75
	particle_material.albedo_color = faction_color.lightened(0.55)
	particle_material.emission = faction_color.lightened(0.25)


func _update_particles() -> void:
	if edge_particles.is_empty():
		return
	var time := maxf(0.0, animation_time)
	for index in edge_particles.size():
		var angle := TAU * float(index) / PARTICLE_COUNT + time * (0.16 if index % 2 == 0 else -0.11)
		var radius := effective_radius * (0.96 + 0.045 * sin(time * 1.8 + index * 2.1))
		var particle := edge_particles[index]
		particle.position = Vector3(cos(angle) * radius, 0.095 + 0.025 * sin(time * 2.0 + index), sin(angle) * radius)
		particle.visible = index % 3 != 0 or sin(time * 1.3 + index) > -0.65
