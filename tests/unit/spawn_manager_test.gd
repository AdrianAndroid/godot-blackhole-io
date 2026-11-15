extends TestCase


func run() -> void:
	var generator := CityGenerator.new()
	var layout := generator.generate(2468)
	var spawn := SpawnManager.new()
	spawn.build(layout)
	expect(spawn.objects.size() == layout.objects.size(), "固定地块全部实例化")
	var districts := {}
	var variants := {}
	for object in spawn.objects.values():
		var entry := spawn.registry.get_entry(object.model_id)
		districts[entry.district] = true
	for placement in layout.objects:
		if placement.variant != "":
			variants[placement.variant] = true
	expect(districts.size() == 4, "商业/住宅/工业/道路四类素材用途")
	expect(variants.has("a") and variants.has("b"), "Commercial 混合配色")
	var target: Swallowable
	for object in spawn.objects.values():
		if object.footprint_radius < 0.38:
			target = object
			break
	expect(target != null, "存在出生可吞物体")
	var hole := HoleActor.new()
	hole.effective_radius = 1.0
	hole.position = target.position
	var swallow := SwallowManager.new()
	var original_count := spawn.objects.size()
	expect(swallow.try_claim(target, hole), "城市物体可进入吞噬")
	swallow.step(1.0)
	expect(target.state == Swallowable.State.SETTLED and not target.visible, "当局物体永久消失")
	for index in 600:
		swallow.step(1.0)
	expect(spawn.objects.size() == original_count, "推进对局时间不补生成")
	var restored := SpawnManager.new()
	restored.build(generator.generate(2468))
	expect(restored.objects.size() == original_count, "重试恢复全部物体")
	var same := true
	for id in spawn.objects:
		same = same and restored.objects[id].position.is_equal_approx(layout.objects[id - 1].position)
	expect(same, "重试实例 ID 和位置恢复")
	expect(generator.generate(2468).signature == layout.signature, "重试布局签名不变")
	swallow.free()
	hole.free()
	spawn.free()
	restored.free()
