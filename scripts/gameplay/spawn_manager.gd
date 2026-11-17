class_name SpawnManager
extends Node3D

var registry := ModelRegistry.new()
var objects: Dictionary = {}
var dynamic_objects: Array[Swallowable] = []
var tower_object: Swallowable
var roads_root: Node3D
var objects_root: Node3D
var water_surface: MeshInstance3D
var wave_time: float = 0.0
var occlusion_fader := OcclusionFader.new()


func build(layout: CityGenerator.Layout) -> void:
	CityVisuals.add_lighting(self)
	CityVisuals.add_ground(self, layout.map_size)
	CityVisuals.add_ground_details(self)
	water_surface = CityVisuals.add_water(self, CityGenerator.WATER_CENTER, CityGenerator.WATER_SIZE)
	roads_root = Node3D.new()
	roads_root.name = "Roads"
	add_child(roads_root)
	CityVisuals.add_roads(roads_root, layout.roads, registry)
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
			object.configure_route(placement.route, float(placement.route_speed), float(placement.get("route_phase", 0.0)))
			dynamic_objects.append(object)
		object.capture_transform()
		objects_root.add_child(object)
		objects[object.object_id] = object
	occlusion_fader.register(objects.values())


func advance_visuals(delta: float, hole_position: Vector3, hole_radius: float, camera: Camera3D = null) -> void:
	wave_time += delta
	if water_surface != null:
		var material := water_surface.material_override as ShaderMaterial
		material.set_shader_parameter("wave_time", wave_time)
	occlusion_fader.step(delta, hole_position, hole_radius, camera)
	if is_instance_valid(tower_object) and tower_object.state != Swallowable.State.SETTLED:
		(tower_object.model_root as TowerVisual).step(delta)


func spawn_tower(position_value: Vector3) -> Swallowable:
	var entry := {"id": "final_tower", "footprint_radius": 3.0, "xp": 0, "score": 0, "coins": 0}
	var model := TowerVisual.new()
	var tower := Swallowable.new()
	tower.name = "FinalTower"
	tower.kind = "tower"
	tower.setup(entry, 1000000, model)
	tower.position = position_value
	tower.sink_duration = 1.2
	tower.capture_transform()
	add_child(tower)
	objects[tower.object_id] = tower
	tower_object = tower
	return tower


func retire_normal(object_id: int) -> void:
	var object: Swallowable = objects.get(object_id)
	if object == null:
		return
	objects.erase(object_id)
	occlusion_fader.unregister(object)
	object.release_visual()
