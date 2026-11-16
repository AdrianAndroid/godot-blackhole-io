class_name CityGenerator
extends RefCounted

const GENERATION_VERSION: int = 4
const MAP_SIZE := Vector2(112, 112)
const ROAD_TILE_SIZE: float = 4.0
const ROAD_COORDINATES: Array[float] = [-48.0, -32.0, -16.0, 0.0, 16.0, 32.0, 48.0]
const BLOCK_COORDINATES: Array[float] = [-40.0, -24.0, -8.0, 8.0, 24.0, 40.0]
const WATER_CENTER := Vector2(50, 0)
const WATER_SIZE := Vector2(12, 112)
const BUILDING_EAST_LIMIT: float = 44.0
const ROAD_EAST_LIMIT: float = 48.0
const TOWER_POSITION := Vector3(40, 0, 46)
const PLACEMENT_CELL_SIZE: float = 8.0
const MAX_FOOTPRINT_RADIUS: float = 4.0
const SMALL_PROP_MODEL_IDS: Array[String] = [
	"cone", "cone", "traffic_light", "construction_light", "road_sign_stop", "road_sign_street", "street_light",
]
const BUILDING_MODEL_IDS: Array[String] = [
	"commercial_low_a", "commercial_low_b", "commercial_low_c", "commercial_a", "commercial_c",
	"skyscraper_a", "skyscraper_b", "skyscraper_c", "house_a", "house_b", "house_c", "house_d",
	"industrial_a", "industrial_b", "industrial_c",
]

class Layout:
	extends RefCounted
	var seed_value: int
	var attempt: int = 0
	var generation_version: int = CityGenerator.GENERATION_VERSION
	var map_size := CityGenerator.MAP_SIZE
	var objects: Array[Dictionary] = []
	var roads: Array[Dictionary] = []
	var routes: Array[PackedVector3Array] = []
	var opponent_radii: Array[float] = [0.22, 0.30, 0.36, 1.80]
	var player_spawn := Vector3.ZERO
	var tower_position := CityGenerator.TOWER_POSITION
	var ordinary_total_score: int = 0
	var target_score: int = 1
	var signature: String = ""
	var placement_cells: Dictionary = {}


func generate(seed_value: int) -> Layout:
	for attempt in 12:
		var layout := _generate_attempt(seed_value, attempt)
		if validate_layout(layout).is_empty():
			layout.signature = layout_signature(layout)
			return layout
	# Return the final deterministic candidate along with its validation errors for diagnostics.
	var fallback := _generate_attempt(seed_value, 11)
	fallback.signature = layout_signature(fallback)
	return fallback


func _generate_attempt(seed_value: int, attempt: int) -> Layout:
	var layout := Layout.new()
	layout.seed_value = seed_value
	layout.attempt = attempt
	var rng := RandomNumberGenerator.new()
	rng.seed = _stream_seed(seed_value, attempt)
	_build_road_network(layout, rng)
	var next_id: int = 1
	for block_x in BLOCK_COORDINATES:
		for block_z in BLOCK_COORDINATES:
			var center := Vector3(block_x, 0, block_z)
			if center.distance_to(layout.tower_position) < 9.0:
				continue
			next_id = _populate_block(layout, center, next_id, rng)
	# Small objects remain available at the intersection where the player starts.
	for starter in [
		Vector3(-2.8, 0, -1.5), Vector3(-1.0, 0, -2.8), Vector3(1.0, 0, -2.8), Vector3(2.8, 0, -1.5),
		Vector3(-2.8, 0, 1.5), Vector3(-1.0, 0, 2.8), Vector3(1.0, 0, 2.8), Vector3(2.8, 0, 1.5),
		Vector3(-4.2, 0, 0), Vector3(4.2, 0, 0), Vector3(0, 0, -4.2), Vector3(0, 0, 4.2),
		Vector3(-6.0, 0, -1.5), Vector3(-6.0, 0, 1.5), Vector3(6.0, 0, -1.5), Vector3(6.0, 0, 1.5),
		Vector3(-1.5, 0, -6.0), Vector3(1.5, 0, -6.0), Vector3(-1.5, 0, 6.0), Vector3(1.5, 0, 6.0),
		Vector3(-4.4, 0, -4.4), Vector3(4.4, 0, -4.4), Vector3(-4.4, 0, 4.4), Vector3(4.4, 0, 4.4),
	]:
		var starter_id: String = SMALL_PROP_MODEL_IDS[next_id % SMALL_PROP_MODEL_IDS.size()]
		if _can_place(layout, starter, 0.24):
			_append_object(layout, _placement(next_id, starter_id, starter, rng))
			next_id += 1
	_populate_dynamic(layout, next_id, rng)
	layout.ordinary_total_score = 0
	for object in layout.objects:
		layout.ordinary_total_score += int(_catalog_entry(object.model_id).score)
	layout.target_score = maxi(1, ceili(float(layout.ordinary_total_score) * 0.75))
	layout.routes = _make_routes(rng)
	return layout


func _build_road_network(layout: Layout, rng: RandomNumberGenerator) -> void:
	# Adjacent four-metre tiles meet exactly. The east bank remains open water.
	var half_tiles := int(MAP_SIZE.x / (ROAD_TILE_SIZE * 2.0))
	for grid_x in range(-half_tiles + 1, half_tiles):
		for grid_z in range(-half_tiles + 1, half_tiles):
			var x := float(grid_x) * ROAD_TILE_SIZE
			var z := float(grid_z) * ROAD_TILE_SIZE
			if not _road_tile_expected(x, z):
				continue
			var vertical := ROAD_COORDINATES.has(x)
			var horizontal := ROAD_COORDINATES.has(z)
			var model_id := "road_crossroad" if vertical and horizontal else "road_straight"
			var rotation_y := 0.0 if vertical else 90.0
			if model_id == "road_crossroad":
				rotation_y = float(rng.randi_range(0, 3)) * 90.0
			layout.roads.append({"model_id": model_id, "position": Vector3(x, 0, z), "rotation_y": rotation_y})


func _road_tile_expected(x: float, z: float) -> bool:
	if x >= ROAD_EAST_LIMIT:
		return false
	return ROAD_COORDINATES.has(x) or ROAD_COORDINATES.has(z)


func _populate_block(layout: Layout, center: Vector3, next_id: int, rng: RandomNumberGenerator) -> int:
	var central := absf(center.x) <= 8.0 and absf(center.z) <= 8.0
	var model_id := _pick_building(rng, center)
	if central:
		model_id = ["commercial_low_a", "commercial_low_b", "commercial_low_c"][rng.randi_range(0, 2)]
	var radius := float(_catalog_entry(model_id).footprint_radius)
	var offsets: Array[Vector3] = []
	if radius >= 2.4:
		offsets.assign([Vector3(0, 0, -4.1), Vector3(0, 0, 4.1)])
	elif radius >= 2.0:
		offsets.assign([Vector3(-3.6, 0, 0), Vector3(3.6, 0, 0)])
	else:
		for x in [-5.25, -1.75, 1.75, 5.25]:
			for z in [-3.8, 3.8]:
				offsets.append(Vector3(x, 0, z))
	for offset in offsets:
		var building_position := center + offset
		# The river stays open instead of hiding partially submerged buildings.
		if building_position.x + radius > BUILDING_EAST_LIMIT:
			continue
		if _can_place(layout, building_position, radius):
			_append_object(layout, _placement(next_id, model_id, building_position, rng))
			next_id += 1
	var prop_count := 14 if central else rng.randi_range(10, 13)
	var prop_offsets := [
		Vector3(-6.8, 0, -4.8), Vector3(-6.8, 0, -1.6), Vector3(-6.8, 0, 1.6), Vector3(-6.8, 0, 4.8),
		Vector3(6.8, 0, -4.8), Vector3(6.8, 0, -1.6), Vector3(6.8, 0, 1.6), Vector3(6.8, 0, 4.8),
		Vector3(-4.8, 0, -6.8), Vector3(-1.6, 0, -6.8), Vector3(1.6, 0, -6.8), Vector3(4.8, 0, -6.8),
		Vector3(-4.8, 0, 6.8), Vector3(-1.6, 0, 6.8), Vector3(1.6, 0, 6.8), Vector3(4.8, 0, 6.8),
	]
	for prop_index in prop_count:
		var prop_id := _pick_prop(rng, central)
		var prop_position: Vector3 = center + prop_offsets[(prop_index * 5 + rng.randi_range(0, 2)) % prop_offsets.size()]
		var prop_radius := float(_catalog_entry(prop_id).footprint_radius)
		if prop_position.x + prop_radius > BUILDING_EAST_LIMIT:
			continue
		if _can_place(layout, prop_position, prop_radius):
			_append_object(layout, _placement(next_id, prop_id, prop_position, rng))
			next_id += 1
	# Keep a reliable supply of level-one targets on every block, not only large scenery.
	for side in 4:
		for along in [-3.2, 3.2]:
			var offset := Vector3.ZERO
			match side:
				0:
					offset = Vector3(-6.15, 0, along)
				1:
					offset = Vector3(6.15, 0, along)
				2:
					offset = Vector3(along, 0, -6.15)
				3:
					offset = Vector3(along, 0, 6.15)
			var prop_position := center + offset
			var prop_id: String = SMALL_PROP_MODEL_IDS[rng.randi_range(0, SMALL_PROP_MODEL_IDS.size() - 1)]
			var prop_radius := float(_catalog_entry(prop_id).footprint_radius)
			if prop_position.x + prop_radius > BUILDING_EAST_LIMIT:
				continue
			if _can_place(layout, prop_position, prop_radius):
				_append_object(layout, _placement(next_id, prop_id, prop_position, rng))
				next_id += 1
	return next_id


func _populate_dynamic(layout: Layout, next_id: int, rng: RandomNumberGenerator) -> void:
	var vehicle_ids := ["sedan", "taxi", "police", "delivery", "ambulance"]
	var vehicle_index := 0
	var pedestrian_index := 0
	for block_x in BLOCK_COORDINATES:
		for block_z in BLOCK_COORDINATES:
			# The easternmost blocks border the river; keep routes on the road grid.
			if block_x >= 40.0:
				continue
			var center := Vector3(block_x, 0, block_z)
			if center.distance_to(layout.tower_position) < 9.0:
				continue
			var pedestrian_route := PackedVector3Array([
				Vector3(block_x - 6.8, 0, block_z - 2.8),
				Vector3(block_x - 6.8, 0, block_z + 6.8),
				Vector3(block_x + 6.8, 0, block_z + 6.8),
				Vector3(block_x + 6.8, 0, block_z - 6.8),
			])
			var pedestrian_speed := rng.randf_range(0.65, 1.05)
			var pedestrians_placed := 0
			for slot in 8:
				if pedestrians_placed >= 4:
					break
				var phase := (float(slot) + 0.15 * float(pedestrian_index % 2)) / 8.0
				if _add_dynamic(layout, next_id, "pedestrian", pedestrian_route, pedestrian_speed, str(pedestrian_index % 4), rng, phase):
					next_id += 1
					pedestrians_placed += 1
				pedestrian_index += 1
			var lane := 0.72 if vehicle_index % 2 == 0 else -0.72
			var vehicle_route := PackedVector3Array([
				Vector3(block_x - 8.0 + lane, 0, block_z - 8.0),
				Vector3(block_x + 8.0 + lane, 0, block_z - 8.0),
				Vector3(block_x + 8.0 + lane, 0, block_z + 8.0),
				Vector3(block_x - 8.0 + lane, 0, block_z + 8.0),
			])
			for phase_index in 12:
				if _add_dynamic(layout, next_id, vehicle_ids[vehicle_index % vehicle_ids.size()], vehicle_route, rng.randf_range(1.4, 2.2), "", rng, float(phase_index) / 12.0):
					next_id += 1
					break
			vehicle_index += 1
	for index in 12:
		var x := 46.5 + float(index % 2) * 4.0
		var z := -44.0 + float(index) * 7.0
		var duck_route := PackedVector3Array([
			Vector3(x, 0, z - 2.0), Vector3(x + 2.2, 0, z - 2.0),
			Vector3(x + 2.2, 0, z + 2.0), Vector3(x, 0, z + 2.0),
		])
		if _add_dynamic(layout, next_id, "duck", duck_route, 0.35 + float(index % 6) * 0.025, "", rng):
			next_id += 1


func _add_dynamic(layout: Layout, id: int, model_id: String, route: PackedVector3Array, speed: float, variant: String, rng: RandomNumberGenerator, phase_ratio: float = 0.0) -> bool:
	var radius := float(_catalog_entry(model_id).footprint_radius)
	var phase := _route_length(route) * clampf(phase_ratio, 0.0, 0.999)
	var start := _point_on_route(route, phase)
	if not _can_place(layout, start, radius):
		return false
	var placement := _placement(id, model_id, start, rng)
	placement["route"] = route
	placement["route_speed"] = speed
	placement["route_phase"] = phase
	placement["variant"] = variant
	_append_object(layout, placement)
	return true


func _route_length(route: PackedVector3Array) -> float:
	var result := 0.0
	for index in route.size():
		result += route[index].distance_to(route[(index + 1) % route.size()])
	return result


func _point_on_route(route: PackedVector3Array, distance: float) -> Vector3:
	var remaining := distance
	for index in route.size():
		var start := route[index]
		var end := route[(index + 1) % route.size()]
		var length := start.distance_to(end)
		if remaining <= length or index == route.size() - 1:
			return start.lerp(end, clampf(remaining / length, 0.0, 1.0))
		remaining -= length
	return route[0]


func validate_layout(layout: Layout) -> Array[String]:
	var errors: Array[String] = []
	var starter_count := 0
	var starter_prop_count := 0
	var static_small_count := 0
	var nearby_buildings := 0
	var districts: Dictionary = {}
	var dynamic_counts := {"vehicles": 0, "characters": 0, "duck": 0}
	for object in layout.objects:
		var entry := _catalog_entry(object.model_id)
		districts[entry.district] = true
		if entry.district == "vehicles":
			dynamic_counts.vehicles += 1
		elif entry.district == "characters":
			dynamic_counts.characters += 1
		elif object.model_id == "duck":
			dynamic_counts.duck += 1
		if object.has("route") and (object.route.size() != 4 or float(object.get("route_speed", 0.0)) <= 0.0):
			errors.append("动态物件路线无效")
		var position: Vector3 = object.position
		if absf(position.x) > layout.map_size.x * 0.5 or absf(position.z) > layout.map_size.y * 0.5:
			errors.append("目标越出地图")
		if float(entry.footprint_radius) < 0.38 and not object.has("route"):
			static_small_count += 1
			if position.distance_to(layout.player_spawn) < 12.0:
				starter_prop_count += 1
		if float(entry.footprint_radius) < 0.38 and position.distance_to(layout.player_spawn) < 12.0:
			starter_count += 1
		if BUILDING_MODEL_IDS.has(str(object.model_id)) and position.distance_to(layout.player_spawn) <= 20.0:
			nearby_buildings += 1
		if position.distance_to(layout.tower_position) < float(entry.footprint_radius) + 4.0:
			errors.append("高塔预留被占用")
		if position.distance_to(layout.player_spawn) < float(entry.footprint_radius) + 0.5:
			errors.append("出生点被物体占用")
	if starter_count < 24 or starter_prop_count < 20 or static_small_count < 280:
		errors.append("缺少出生小物体或全图静态小物件")
	if nearby_buildings < 8:
		errors.append("出生点 20 米内建筑不足 8 栋")
	if dynamic_counts.vehicles < 20 or dynamic_counts.characters < 80 or dynamic_counts.duck < 12:
		errors.append("车辆/行人/鸭子密度不足")
	for required_district in ["commercial", "suburban", "industrial", "roads"]:
		if not districts.has(required_district):
			errors.append("四类素材分区不完整")
	var validation_cells: Dictionary = {}
	for object in layout.objects:
		var cell := _cell(object.position)
		for x in range(cell.x - 1, cell.x + 2):
			for z in range(cell.y - 1, cell.y + 2):
				for other in validation_cells.get(Vector2i(x, z), []):
					var first_radius := float(_catalog_entry(object.model_id).footprint_radius)
					var second_radius := float(_catalog_entry(other.model_id).footprint_radius)
					if object.position.distance_to(other.position) + 0.001 < first_radius + second_radius:
						errors.append("物体非法重叠")
						return errors
		if not validation_cells.has(cell):
			validation_cells[cell] = []
		validation_cells[cell].append(object)
	var expected_roads := 0
	var half_tiles := int(MAP_SIZE.x / (ROAD_TILE_SIZE * 2.0))
	for grid_x in range(-half_tiles + 1, half_tiles):
		for grid_z in range(-half_tiles + 1, half_tiles):
			if _road_tile_expected(float(grid_x) * ROAD_TILE_SIZE, float(grid_z) * ROAD_TILE_SIZE):
				expected_roads += 1
	if layout.roads.size() != expected_roads:
		errors.append("连续道路地块数量错误")
	for road in layout.roads:
		if absf(road.position.x) + ROAD_TILE_SIZE * 0.5 > layout.map_size.x * 0.5 or absf(road.position.z) + ROAD_TILE_SIZE * 0.5 > layout.map_size.y * 0.5:
			errors.append("道路越出无缝网格")
	if layout.routes.size() != 4:
		errors.append("对手路线数量错误")
	else:
		if layout.routes[3][0].distance_to(layout.player_spawn) < 12.0:
			errors.append("出生点被大型对手威胁")
	var simulated_growth := GrowthManager.new()
	var simulated_score := 0
	var growth_order: Array[Dictionary] = layout.objects.duplicate()
	growth_order.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_radius := float(_catalog_entry(first.model_id).footprint_radius)
		var second_radius := float(_catalog_entry(second.model_id).footprint_radius)
		if is_equal_approx(first_radius, second_radius):
			return int(first.id) < int(second.id)
		return first_radius < second_radius
	)
	for object in growth_order:
		if simulated_score >= layout.target_score:
			break
		var entry := _catalog_entry(object.model_id)
		if float(entry.footprint_radius) >= simulated_growth.radius:
			break
		simulated_growth.add_experience(int(entry.xp))
		simulated_score += int(entry.score)
	if simulated_score < layout.target_score:
		errors.append("连续成长路径无法达到目标")
	if layout.target_score != maxi(1, ceili(float(layout.ordinary_total_score) * 0.75)):
		errors.append("目标预算错误")
	return errors


func layout_signature(layout: Layout) -> String:
	var parts: Array[String] = [
		str(layout.generation_version), str(layout.seed_value), str(layout.attempt),
		"map:%.3f:%.3f" % [layout.map_size.x, layout.map_size.y],
		"spawn:%s" % str(layout.player_spawn), "tower:%s" % str(layout.tower_position),
		"budget:%d:%d" % [layout.ordinary_total_score, layout.target_score],
		"opponents:%s" % str(layout.opponent_radii),
	]
	for road in layout.roads:
		parts.append("road:%s:%.3f:%.3f:%.1f" % [road.model_id, road.position.x, road.position.z, road.rotation_y])
	for object in layout.objects:
		parts.append("%d:%s:%.3f:%.3f:%.1f:%s" % [object.id, object.model_id, object.position.x, object.position.z, object.rotation_y, object.variant])
		if object.has("route"):
			parts.append("speed:%.4f:phase:%.4f" % [float(object.route_speed), float(object.get("route_phase", 0.0))])
			for point in object.route:
				parts.append("dynamic:%.3f:%.3f" % [point.x, point.z])
	for route in layout.routes:
		for point in route:
			parts.append("r:%.3f:%.3f" % [point.x, point.z])
	return "\n".join(parts).sha256_text()


func _placement(id: int, model_id: String, position: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	return {"id": id, "model_id": model_id, "position": position, "rotation_y": float(rng.randi_range(0, 3)) * 90.0, "variant": ["", "a", "b"][rng.randi_range(0, 2)]}


func _pick_building(rng: RandomNumberGenerator, position: Vector3) -> String:
	var choices: Array[String]
	if position.z < -8.0:
		choices = ["commercial_low_a", "commercial_low_b", "commercial_low_c", "commercial_a", "commercial_c", "skyscraper_a", "skyscraper_b", "skyscraper_c"]
	elif position.z > 8.0 and position.x < 0.0:
		choices = ["industrial_a", "industrial_b", "industrial_c"]
	else:
		choices = ["house_a", "house_b", "house_c", "house_d", "commercial_low_a", "commercial_low_b"]
	return choices[rng.randi_range(0, choices.size() - 1)]


func _pick_prop(rng: RandomNumberGenerator, central: bool) -> String:
	var choices: Array[String] = []
	if central:
		choices.assign(["cone", "cone", "traffic_light", "street_light", "tree", "construction_barrier", "road_sign_street", "parasol", "planter"])
	else:
		choices.assign(["cone", "traffic_light", "street_light", "tree", "planter", "dumpster", "construction_light", "road_sign_stop", "container", "parasol"])
	return choices[rng.randi_range(0, choices.size() - 1)]


func _append_object(layout: Layout, placement: Dictionary) -> void:
	layout.objects.append(placement)
	var cell := _cell(placement.position)
	if not layout.placement_cells.has(cell):
		layout.placement_cells[cell] = []
	layout.placement_cells[cell].append(placement)


func _cell(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / PLACEMENT_CELL_SIZE), floori(position.z / PLACEMENT_CELL_SIZE))


func _can_place(layout: Layout, position: Vector3, radius: float) -> bool:
	if position.distance_to(layout.player_spawn) < radius + 0.65:
		return false
	if position.distance_to(layout.tower_position) < radius + 4.0:
		return false
	var cell := _cell(position)
	var reach := ceili((radius + MAX_FOOTPRINT_RADIUS + 0.15) / PLACEMENT_CELL_SIZE)
	for x in range(cell.x - reach, cell.x + reach + 1):
		for z in range(cell.y - reach, cell.y + reach + 1):
			for object in layout.placement_cells.get(Vector2i(x, z), []):
				var other_radius := float(_catalog_entry(object.model_id).footprint_radius)
				if position.distance_to(object.position) < radius + other_radius + 0.15:
					return false
	return true


func _make_routes(rng: RandomNumberGenerator) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	var centers := [Vector2(-32, 0), Vector2(32, -8), Vector2(8, 32), Vector2(-16, -38)]
	var extents := [Vector2(10, 14), Vector2(10, 12), Vector2(14, 7), Vector2(12, 8)]
	for index in 4:
		var center: Vector2 = centers[index]
		var extent: Vector2 = extents[index]
		var route := PackedVector3Array([
			Vector3(center.x - extent.x, 0, center.y - extent.y),
			Vector3(center.x + extent.x, 0, center.y - extent.y),
			Vector3(center.x + extent.x, 0, center.y + extent.y),
			Vector3(center.x - extent.x, 0, center.y + extent.y)
		])
		if rng.randi_range(0, 1) == 1:
			route.reverse()
		result.append(route)
	return result


func _catalog_entry(model_id: String) -> Dictionary:
	return CatalogCache.entries.get(model_id, {})


func _stream_seed(seed_value: int, attempt: int) -> int:
	return abs((seed_value * 636413622 + attempt * 1442695041 + GENERATION_VERSION * 97) % 9223372036854775806) + 1


class CatalogCache:
	extends RefCounted
	static var entries: Dictionary = _load_entries()

	static func _load_entries() -> Dictionary:
		var file := FileAccess.open("res://config/model_catalog.json", FileAccess.READ)
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		var result := {}
		for entry in data.models:
			result[entry.id] = entry
		return result
