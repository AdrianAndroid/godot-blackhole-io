class_name CityGenerator
extends RefCounted

const GENERATION_VERSION: int = 1
const MAP_SIZE := Vector2(80, 80)

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
	var tower_position := Vector3(24, 0, 30)
	var ordinary_total_score: int = 0
	var target_score: int = 1
	var signature: String = ""


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
	var next_id: int = 1
	for gz in range(-4, 5):
		for gx in range(-4, 5):
			var center := Vector3(gx * 8.0, 0, gz * 8.0)
			var road_id := "road_crossroad" if abs(gx) <= 1 and abs(gz) <= 1 else "tile_low"
			layout.roads.append({"model_id": road_id, "position": center, "rotation_y": float(rng.randi_range(0, 3)) * 90.0})
			if center.distance_to(layout.tower_position) < 10.0 or center.x > 26.0:
				continue
			var central: bool = abs(gx) <= 1 and abs(gz) <= 1
			if not central:
				var model_id := _pick_building(rng, center)
				var entry := _catalog_entry(model_id)
				if _can_place(layout.objects, center, float(entry.footprint_radius)):
					layout.objects.append(_placement(next_id, model_id, center, rng))
					next_id += 1
			var prop_count := 3 if central else rng.randi_range(1, 2)
			for prop_index in prop_count:
				var prop_id := _pick_prop(rng, central)
				var offset := Vector3(3.65, 0, 0) if prop_index % 2 == 0 else Vector3(0, 0, 3.65)
				if central:
					offset = Vector3((prop_index - 1) * 2.4 + gx * 1.2, 0, (gz % 2) * 2.4)
				var prop_position := center + offset
				var prop_entry := _catalog_entry(prop_id)
				if prop_position.distance_to(layout.player_spawn) < 1.0:
					continue
				if _can_place(layout.objects, prop_position, float(prop_entry.footprint_radius)):
					layout.objects.append(_placement(next_id, prop_id, prop_position, rng))
					next_id += 1
	# A guaranteed deterministic starter patch, separated from the city stream's building choices.
	for starter in [
		Vector3(-4.8, 0, -3.0), Vector3(-1.6, 0, -3.0), Vector3(1.6, 0, -3.0), Vector3(4.8, 0, -3.0),
		Vector3(-4.8, 0, 3.0), Vector3(-1.6, 0, 3.0), Vector3(1.6, 0, 3.0), Vector3(4.8, 0, 3.0)
	]:
		var starter_id := "cone" if next_id % 2 == 0 else "traffic_light"
		if _can_place(layout.objects, starter, 0.24):
			layout.objects.append(_placement(next_id, starter_id, starter, rng))
			next_id += 1
	layout.ordinary_total_score = 0
	for object in layout.objects:
		layout.ordinary_total_score += int(_catalog_entry(object.model_id).score)
	layout.target_score = maxi(1, ceili(float(layout.ordinary_total_score) * 0.75))
	layout.routes = _make_routes(rng)
	return layout


func validate_layout(layout: Layout) -> Array[String]:
	var errors: Array[String] = []
	var starter_count := 0
	var districts: Dictionary = {}
	for object in layout.objects:
		var entry := _catalog_entry(object.model_id)
		districts[entry.district] = true
		var position: Vector3 = object.position
		if absf(position.x) > layout.map_size.x * 0.5 or absf(position.z) > layout.map_size.y * 0.5:
			errors.append("目标越出地图")
		if float(entry.footprint_radius) < 0.38 and position.distance_to(layout.player_spawn) < 12.0:
			starter_count += 1
		if position.distance_to(layout.tower_position) < float(entry.footprint_radius) + 4.0:
			errors.append("高塔预留被占用")
		if position.distance_to(layout.player_spawn) < float(entry.footprint_radius) + 0.5:
			errors.append("出生点被物体占用")
	if starter_count < 4:
		errors.append("缺少出生小物体")
	if districts.size() != 4:
		errors.append("四类素材分区不完整")
	for first_index in layout.objects.size():
		var first: Dictionary = layout.objects[first_index]
		var first_radius := float(_catalog_entry(first.model_id).footprint_radius)
		for second_index in range(first_index + 1, layout.objects.size()):
			var second: Dictionary = layout.objects[second_index]
			var second_radius := float(_catalog_entry(second.model_id).footprint_radius)
			if first.position.distance_to(second.position) + 0.001 < first_radius + second_radius:
				errors.append("物体非法重叠")
				return errors
	if layout.routes.size() != 4:
		errors.append("对手路线数量错误")
	else:
		if layout.routes[3][0].distance_to(layout.player_spawn) < 12.0:
			errors.append("出生点被大型对手威胁")
	var simulated_growth := GrowthManager.new()
	var simulated_score := 0
	var consumed: Dictionary = {}
	while simulated_score < layout.target_score:
		var found := false
		for object in layout.objects:
			if consumed.has(object.id):
				continue
			var entry := _catalog_entry(object.model_id)
			if float(entry.footprint_radius) < simulated_growth.radius:
				consumed[object.id] = true
				simulated_growth.add_experience(int(entry.xp))
				simulated_score += int(entry.score)
				found = true
				if simulated_score >= layout.target_score:
					break
		if not found:
			errors.append("连续成长路径无法达到目标")
			break
	if layout.target_score != maxi(1, ceili(float(layout.ordinary_total_score) * 0.75)):
		errors.append("目标预算错误")
	return errors


func layout_signature(layout: Layout) -> String:
	var parts: Array[String] = [str(layout.generation_version), str(layout.seed_value), str(layout.attempt)]
	for object in layout.objects:
		parts.append("%d:%s:%.3f:%.3f:%.1f:%s" % [object.id, object.model_id, object.position.x, object.position.z, object.rotation_y, object.variant])
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
		choices = ["industrial_a", "industrial_b", "industrial_c", "tank", "container"]
	else:
		choices = ["house_a", "house_b", "house_c", "house_d", "commercial_low_a", "parasol"]
	return choices[rng.randi_range(0, choices.size() - 1)]


func _pick_prop(rng: RandomNumberGenerator, central: bool) -> String:
	var choices: Array[String] = []
	if central:
		choices.assign(["cone", "cone", "traffic_light", "street_light", "tree"])
	else:
		choices.assign(["cone", "traffic_light", "street_light", "tree", "planter", "dumpster"])
	return choices[rng.randi_range(0, choices.size() - 1)]


func _can_place(objects: Array[Dictionary], position: Vector3, radius: float) -> bool:
	for object in objects:
		var other_radius := float(_catalog_entry(object.model_id).footprint_radius)
		if position.distance_to(object.position) < radius + other_radius + 0.15:
			return false
	return true


func _make_routes(rng: RandomNumberGenerator) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	var centers := [Vector2(-24, 0), Vector2(24, -4), Vector2(4, 24), Vector2(-12, -26)]
	var extents := [Vector2(5, 9), Vector2(5, 8), Vector2(8, 4), Vector2(7, 5)]
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
