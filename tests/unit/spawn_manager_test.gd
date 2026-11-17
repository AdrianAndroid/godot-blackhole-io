extends TestCase


func run() -> void:
	var generator := CityGenerator.new()
	var layout := generator.generate(2468)
	var spawn := SpawnManager.new()
	spawn.build(layout)
	expect(spawn.objects.size() == layout.objects.size(), "固定地块全部实例化")
	var crossroads := layout.roads.filter(func(road: Dictionary) -> bool: return road.model_id == "road_crossroad")
	var crosswalks := spawn.roads_root.get_node_or_null("Crosswalks") as MultiMeshInstance3D
	expect(crosswalks != null, "参考路口具有共享批处理斑马线")
	expect(crosswalks.multimesh.instance_count == crossroads.size() * 32, "每个十字路口四入口各八条细纹")
	expect(crosswalks.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and crosswalks.multimesh.mesh is BoxMesh, "斑马线使用共享轻量网格且不投射阴影")
	var stripe_height := CityVisuals._crosswalk_transform(crossroads[0], 0, 0).origin.y
	expect(stripe_height > 0.08 and stripe_height < 0.09, "斑马线变换贴合实际道路表面")
	var districts := {}
	var variants := {}
	for object in spawn.objects.values():
		var entry := spawn.registry.get_entry(object.model_id)
		districts[entry.district] = true
	for placement in layout.objects:
		if placement.variant != "":
			variants[placement.variant] = true
	var required_districts := ["commercial", "suburban", "industrial", "roads"]
	expect(required_districts.all(func(district: String) -> bool: return districts.has(district)), "商业/住宅/工业/道路四类素材用途")
	expect(districts.has("vehicles") and districts.has("characters"), "车辆和行人进入正式城市场景")
	expect(variants.has("a") and variants.has("b"), "Commercial 混合配色")
	var target: Swallowable
	for object in spawn.objects.values():
		if object.footprint_radius < 0.38:
			target = object
			break
	expect(target != null, "存在出生可吞物体")
	var walker: Swallowable
	for object in spawn.objects.values():
		if object.model_id == "pedestrian":
			walker = object
			break
	expect(walker != null and walker._animation_player != null, "动态行人具有跑步动画播放器")
	var walker_start := walker.position
	walker.advance_route(0.5)
	expect(walker.position.distance_to(walker_start) > 0.1, "行人按固定步进沿路线跑步")
	expect(walker._animation_player.current_animation_position > 0.0, "跑步动画随逻辑时间推进")
	expect(walker.claim(99), "动态物件可进入认领事务")
	var claimed_position := walker.position
	walker.advance_route(0.5)
	expect(walker.position.is_equal_approx(claimed_position), "认领后路线和动画立即停止")
	walker.cancel()
	var hole := HoleActor.new()
	hole.effective_radius = 1.0
	hole.position = target.position
	var swallow := SwallowManager.new()
	var original_count := spawn.objects.size()
	expect(swallow.try_claim(target, hole), "城市物体可进入吞噬")
	swallow.step(1.0)
	expect(target.state == Swallowable.State.SETTLED and not target.visible, "当局物体永久消失")
	spawn.retire_normal(target.object_id)
	expect(not spawn.objects.has(target.object_id) and target.model_root == null, "结算后释放渲染资源引用并保留事务状态")
	for index in 600:
		swallow.step(1.0)
	expect(spawn.objects.size() == original_count - 1, "推进对局时间不补生成")
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
