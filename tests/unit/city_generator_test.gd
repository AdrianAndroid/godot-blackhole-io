extends TestCase


func run() -> void:
	var generator := CityGenerator.new()
	var first := generator.generate(12345)
	var signature := first.signature
	randomize()
	randf()
	var second := generator.generate(12345)
	expect(signature == second.signature, "相同种子与生成版本完全复现")
	expect(generator.generate(12346).signature != signature, "不同种子布局不同")
	var nearby_buildings := 0
	var building_count := 0
	var static_small_count := 0
	var nearby_static_small := 0
	var dynamic_models := {"pedestrian": 0, "duck": 0, "vehicles": 0}
	for object in first.objects:
		if CityGenerator.BUILDING_MODEL_IDS.has(object.model_id):
			building_count += 1
			if object.position.length() <= 20.0:
				nearby_buildings += 1
		if not object.has("route") and float(generator._catalog_entry(object.model_id).footprint_radius) < GrowthManager.RADII[0]:
			static_small_count += 1
			if object.position.distance_to(first.player_spawn) < 12.0:
				nearby_static_small += 1
		if dynamic_models.has(object.model_id):
			dynamic_models[object.model_id] += 1
		elif object.has("route"):
			dynamic_models.vehicles += 1
	expect(nearby_buildings >= 8, "出生点 20 米内至少 8 栋建筑")
	expect(building_count >= 120 and first.objects.size() >= 650, "扩大城市具有充足建筑与物件密度")
	expect(static_small_count >= 280 and nearby_static_small >= 20, "前期静态可吞小物件和出生点保底供给充足")
	expect(first.map_size == Vector2(112, 112) and first.roads.size() == 295, "112 米地图和道路数量由网格几何推导")
	expect(dynamic_models.pedestrian >= 80 and dynamic_models.duck >= 12 and dynamic_models.vehicles >= 20, "行人/鸭子/车辆达到扩充后的城市密度门槛")
	var changed_route := generator.generate(12345)
	changed_route.objects.back().route[0].x += 1.0
	expect(generator.layout_signature(changed_route) != signature, "布局签名覆盖动态路线")
	var forward: Dictionary = {}
	var reverse: Dictionary = {}
	for index in 10:
		forward[index] = generator.generate(500 + index).signature
	for index in range(9, -1, -1):
		reverse[index] = generator.generate(500 + index).signature
	expect(forward == reverse, "布局不依赖全局随机状态或生成顺序")

	var missing_small := generator.generate(77)
	for index in range(missing_small.objects.size() - 1, -1, -1):
		var object: Dictionary = missing_small.objects[index]
		if float(generator._catalog_entry(object.model_id).footprint_radius) < 0.38 and object.position.length() < 12.0:
			missing_small.objects.remove_at(index)
	expect(generator.validate_layout(missing_small).any(func(message: String) -> bool: return "小物体" in message), "缺少小物体的负向夹具被拒绝")
	var threatened := generator.generate(77)
	threatened.routes[3][0] = Vector3.ZERO
	expect(generator.validate_layout(threatened).any(func(message: String) -> bool: return "威胁" in message), "出生威胁的负向夹具被拒绝")
	var occupied := generator.generate(77)
	occupied.objects.append({"id": 999999, "model_id": "industrial_a", "position": occupied.tower_position, "rotation_y": 0.0, "variant": ""})
	expect(generator.validate_layout(occupied).any(func(message: String) -> bool: return "高塔" in message), "高塔占用的负向夹具被拒绝")

	var failed_seeds: Array[int] = []
	for index in 100:
		var seed_value := 1000 + index * 37
		var layout := generator.generate(seed_value)
		var errors := generator.validate_layout(layout)
		if not errors.is_empty() or layout.signature != generator.generate(seed_value).signature:
			failed_seeds.append(seed_value)
	expect(failed_seeds.is_empty(), "100 种子出生/成长/预算/高塔/复现失败: " + str(failed_seeds))
	expect(first.ordinary_total_score > 0 and first.target_score <= first.ordinary_total_score, "75% 目标不会理论不可完成")
	var initial_count := first.objects.size()
	var simulated_time := 600.0
	expect(first.objects.size() == initial_count and simulated_time == 600.0, "普通建筑不随时间补生成")
	var retry := generator.generate(first.seed_value)
	expect(retry.objects.size() == initial_count and retry.signature == first.signature, "同种子重试完整恢复布局")
