extends TestCase


func run() -> void:
	var registry := ModelRegistry.new()
	var errors := registry.validate(true)
	expect(errors.is_empty(), "正式模型注册表错误: " + str(errors))
	expect(registry.entries.size() == 29, "应注册 29 个模型")

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
