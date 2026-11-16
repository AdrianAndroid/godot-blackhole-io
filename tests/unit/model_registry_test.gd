extends TestCase


func run() -> void:
	var registry := ModelRegistry.new()
	var errors := registry.validate(true)
	expect(errors.is_empty(), "正式模型注册表错误: " + str(errors))
	expect(registry.entries.size() == 40, "应注册 40 个正式模型")

	var missing := ModelRegistry.new("res://config/not_found.json")
	expect(not missing.validate(false).is_empty(), "缺失目录必须失败")

	var invalid := ModelRegistry.new()
	invalid.entries["bad_scale"] = invalid.entries["cone"].duplicate(true)
	invalid.entries["bad_scale"]["scale"] = 0.0
	invalid.entries["bad_radius"] = invalid.entries["cone"].duplicate(true)
	invalid.entries["bad_radius"]["footprint_radius"] = -1.0
	var invalid_errors := invalid.validate(false)
	expect(invalid_errors.any(func(message: String) -> bool: return "缩放" in message), "非正缩放必须失败")
	expect(invalid_errors.any(func(message: String) -> bool: return "半径" in message), "负半径必须失败")
	expect(not registry._valid_bounds(AABB()), "空视觉包围盒必须失败")
	invalid.entries["missing_resource"] = invalid.entries["cone"].duplicate(true)
	invalid.entries["missing_resource"]["path"] = "res://assets/game/models/missing.glb"
	var visual_errors := invalid.validate(true)
	expect(visual_errors.any(func(message: String) -> bool: return "资源不存在" in message), "缺失模型资源必须失败")

	var cone := registry.instantiate("cone")
	expect(cone != null, "交通锥应可实例化")
	if cone != null:
		expect_near(cone.scale.x, 3.0, 0.0001, "统一缩放")
		expect(is_equal_approx(cone.position.y, 0.0), "地面原点")
		cone.free()
	var commercial := registry.instantiate("commercial_low_a", "a")
	var meshes := commercial.find_children("*", "MeshInstance3D", true, false)
	var textured_surfaces := 0
	expect(not meshes.is_empty(), "商业建筑包含实时网格")
	for node in meshes:
		var mesh := node as MeshInstance3D
		expect(mesh.material_override == null, "配色使用逐表面材质而非整网格覆盖")
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material != null and material.albedo_texture != null and material.albedo_texture.resource_path.ends_with("variation-a.png"):
				textured_surfaces += 1
	expect(textured_surfaces > 0, "商业配色纹理实际应用到表面材质")
	commercial.free()
	var pedestrian := registry.instantiate("pedestrian", "2")
	var runner := registry._find_animation_player(pedestrian)
	expect(runner != null and runner.has_animation("run"), "行人合并真实跑步骨骼动画")
	expect(runner.playback_process_mode == AnimationPlayer.ANIMATION_PROCESS_MANUAL, "跑步动画由固定步进驱动")
	pedestrian.free()
	var duck := registry.instantiate("duck")
	expect(duck is DuckVisual and registry._valid_bounds(registry.measure_bounds(duck, Transform3D.IDENTITY)), "程序化鸭子是有效实时 3D 网格")
	duck.free()
