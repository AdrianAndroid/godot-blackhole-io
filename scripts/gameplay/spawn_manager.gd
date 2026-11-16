class_name SpawnManager
extends Node3D

var registry := ModelRegistry.new()
var objects: Dictionary = {}
var roads_root: Node3D
var objects_root: Node3D
var water_surface: MeshInstance3D
var wave_time: float = 0.0
var occlusion_fader := OcclusionFader.new()


func build(layout: CityGenerator.Layout) -> void:
	CityVisuals.add_lighting(self)
	CityVisuals.add_ground(self, layout.map_size)
	CityVisuals.add_ground_details(self)
	water_surface = CityVisuals.add_water(self, Vector2(34, 0), Vector2(12, 80))
	roads_root = Node3D.new()
	roads_root.name = "Roads"
	add_child(roads_root)
	for road in layout.roads:
		var model := registry.instantiate(road.model_id)
		model.position += road.position
		model.rotation_degrees.y += float(road.rotation_y)
		CityVisuals.style_road(model)
		roads_root.add_child(model)
	objects_root = Node3D.new()
	objects_root.name = "Objects"
	add_child(objects_root)
	for placement in layout.objects:
		var entry := registry.get_entry(placement.model_id)
		var model := registry.instantiate(placement.model_id, placement.variant)
		var object := Swallowable.new()
		object.name = "Object_%04d" % placement.id
		object.setup(entry, placement.id, model)
		object.position = placement.position
		object.rotation_degrees.y = float(placement.rotation_y)
		if placement.has("route"):
			object.configure_route(placement.route, float(placement.route_speed))
		object.capture_transform()
		objects_root.add_child(object)
		objects[object.object_id] = object
	occlusion_fader.register(objects.values())


func advance_visuals(delta: float, hole_position: Vector3, hole_radius: float) -> void:
	wave_time += delta
	if water_surface != null:
		var material := water_surface.material_override as ShaderMaterial
		material.set_shader_parameter("wave_time", wave_time)
	occlusion_fader.step(delta, hole_position, hole_radius)


func spawn_tower(position_value: Vector3) -> Swallowable:
	var entry := {"id": "golden_tower", "footprint_radius": 3.0, "xp": 0, "score": 0, "coins": 0}
	var model := registry.instantiate("skyscraper_b")
	model.scale *= 1.5
	_tint_gold(model)
	var tower := Swallowable.new()
	tower.name = "GoldenTower"
	tower.kind = "tower"
	tower.setup(entry, 1000000, model)
	tower.position = position_value
	tower.sink_duration = 1.2
	tower.capture_transform()
	add_child(tower)
	objects[tower.object_id] = tower
	return tower


func _tint_gold(node: Node) -> void:
	if node is MeshInstance3D:
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color("ffc83d")
		gold.metallic = 0.65
		gold.roughness = 0.25
		gold.emission_enabled = true
		gold.emission = Color("8a4d00")
		gold.emission_energy_multiplier = 0.35
		node.material_override = gold
	for child in node.get_children():
		_tint_gold(child)
