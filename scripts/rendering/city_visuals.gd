class_name CityVisuals
extends RefCounted


static func add_lighting(root: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "Environment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fc9e8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e7f5")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 1.5
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)


static func add_ground(root: Node3D, map_size: Vector2) -> MeshInstance3D:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(map_size.x, 0.25, map_size.y)
	ground.mesh = mesh
	ground.position.y = -0.15
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a8b98b")
	material.roughness = 0.95
	ground.material_override = material
	root.add_child(ground)
	return ground


static func add_water(root: Node3D, center: Vector2, size: Vector2) -> MeshInstance3D:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var mesh := PlaneMesh.new()
	mesh.size = size
	water.mesh = mesh
	water.position = Vector3(center.x, 0.025, center.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4f9fc4")
	material.metallic = 0.15
	material.roughness = 0.3
	water.material_override = material
	water.set_meta("surface", "water")
	root.add_child(water)
	return water


static func add_district(root: Node3D, district_name: String) -> Node3D:
	var district := Node3D.new()
	district.name = district_name.capitalize()
	district.set_meta("district_group", district_name)
	root.add_child(district)
	return district
