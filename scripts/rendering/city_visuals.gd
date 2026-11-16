class_name CityVisuals
extends RefCounted

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float wave_time = 0.0;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float broad = sin(world_position.z * 0.72 + world_position.x * 0.31 + wave_time * 0.8);
	float crossing = sin(world_position.z * 2.6 - world_position.x * 1.15 - wave_time * 1.3);
	float crest = smoothstep(0.82, 1.0, broad * 0.72 + crossing * 0.28);
	vec3 deep = vec3(0.015, 0.34, 0.66);
	vec3 shallow = vec3(0.025, 0.61, 0.82);
	ALBEDO = mix(deep, shallow, 0.46 + broad * 0.18) + crest * vec3(0.08, 0.20, 0.24);
	ROUGHNESS = 0.3;
	METALLIC = 0.16;
	SPECULAR = 0.65;
	EMISSION = crest * vec3(0.01, 0.055, 0.075);
}
"""


static func add_lighting(root: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "Environment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("83c6e8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e5edff")
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color.WHITE
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 70.0
	root.add_child(sun)


static func add_ground(root: Node3D, map_size: Vector2) -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(map_size.x, 0.25, map_size.y)
	ground.mesh = mesh
	ground.position.y = -0.15
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("827f89")
	material.roughness = 0.96
	ground.material_override = material
	root.add_child(ground)
	return ground


static func add_ground_details(root: Node3D) -> void:
	var grass_root := Node3D.new()
	grass_root.name = "GrassIslands"
	root.add_child(grass_root)
	for center in [Vector2(-24, -24), Vector2(-24, 8), Vector2(8, 24), Vector2(24, -8)]:
		var grass := MeshInstance3D.new()
		grass.name = "Grass"
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(10.5, 10.5)
		grass.mesh = mesh
		grass.position = Vector3(center.x, 0.012, center.y)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("3e762f")
		material.roughness = 0.98
		grass.material_override = material
		grass_root.add_child(grass)


static func add_water(root: Node3D, center: Vector2, size: Vector2) -> MeshInstance3D:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var mesh := PlaneMesh.new()
	mesh.size = size
	water.mesh = mesh
	water.position = Vector3(center.x, 0.035, center.y)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WATER_SHADER
	material.shader = shader
	water.material_override = material
	water.set_meta("surface", "water")
	root.add_child(water)
	var bank := MeshInstance3D.new()
	bank.name = "RiverBank"
	var bank_mesh := BoxMesh.new()
	bank_mesh.size = Vector3(0.34, 0.28, size.y)
	bank.mesh = bank_mesh
	bank.position = Vector3(center.x - size.x * 0.5 - 0.12, 0.10, center.y)
	var bank_material := StandardMaterial3D.new()
	bank_material.albedo_color = Color("aaa6b0")
	bank_material.roughness = 0.9
	bank.material_override = bank_material
	root.add_child(bank)
	return water


static func style_road(model: Node3D) -> void:
	if model is MeshInstance3D:
		for surface in model.mesh.get_surface_count():
			var source: Material = model.get_active_material(surface)
			if source is StandardMaterial3D:
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_color = Color(1.12, 1.10, 1.16, 1.0)
				material.roughness = 0.92
				material.emission_enabled = true
				material.emission = Color("26242e")
				material.emission_energy_multiplier = 0.16
				model.set_surface_override_material(surface, material)
	for child in model.get_children():
		style_road(child)


static func add_district(root: Node3D, district_name: String) -> Node3D:
	var district := Node3D.new()
	district.name = district_name.capitalize()
	district.set_meta("district_group", district_name)
	root.add_child(district)
	return district
