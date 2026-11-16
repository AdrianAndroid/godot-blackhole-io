extends TestCase


func run() -> void:
	var spawn := SpawnManager.new()
	spawn.build(CityGenerator.new().generate(13579))
	var target: Swallowable
	for object in spawn.objects.values():
		if object.footprint_radius > 2.0:
			target = object
			break
	expect(target != null, "存在用于遮挡检查的大型建筑")
	if target == null:
		spawn.free()
		return
	var fader := spawn.occlusion_fader
	var state: Dictionary = fader.states[target.get_instance_id()]
	var original_color := state.records[0].color as Color
	var original_shadow := int(state.records[0].shadow)
	fader.step(0.1, target.position, 0.38)
	expect(fader.fade_amount(target) > 0.0 and fader.fade_amount(target) < 1.0, "遮挡透明度平滑过渡而非瞬间跳变")
	fader.step(0.1, target.position, 0.38)
	expect(is_equal_approx(fader.fade_amount(target), 1.0), "进入不可吞建筑下方后完全进入淡出状态")
	var material := state.records[0].material as StandardMaterial3D
	expect(material.albedo_color.a < 0.25 and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "建筑材质真实变为半透明")
	expect(state.records[0].mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "淡出建筑不再投下遮光阴影")
	var settled_writes := fader.material_writes
	fader.step(0.1, target.position, 0.38)
	expect(fader.material_writes == settled_writes, "遮挡状态不变时不重复写材质和阴影")
	fader.step(0.5, Vector3(-35, 0, -35), 0.38)
	expect(is_equal_approx(fader.fade_amount(target), 0.0), "离开后平滑恢复")
	expect(is_equal_approx(material.albedo_color.a, original_color.a) and material.transparency == int(state.records[0].transparency), "原始材质颜色和透明模式完整恢复")
	expect(state.records[0].mesh.cast_shadow == original_shadow, "原始阴影设置完整恢复")
	spawn.advance_visuals(0.25, Vector3.ZERO, 0.38)
	var water_material := spawn.water_surface.material_override as ShaderMaterial
	expect(is_equal_approx(spawn.wave_time, 0.25) and water_material.get_shader_parameter("wave_time") == 0.25, "水波只由固定逻辑步进驱动")
	fader.unregister(target)
	fader.step(0.5, target.position, 0.38)
	expect(not fader.states.has(target.get_instance_id()), "已吞噬建筑退出遮挡更新集合")
	spawn.free()
