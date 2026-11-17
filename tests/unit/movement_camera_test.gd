extends TestCase


func run() -> void:
	var actor := HoleActor.new()
	actor.map_size = Vector2(20, 30)
	actor.position = Vector3(-2, 0, 0)
	actor.step(0.5, Vector2.RIGHT)
	var land_position := actor.position
	actor.position = Vector3(2, 0, 0)
	actor.step(0.5, Vector2.RIGHT)
	expect(actor.position.is_equal_approx(land_position + Vector3(4, 0, 0)), "水面和陆地等速")
	expect(is_zero_approx(actor.position.y), "移动保持 Y 平面")
	# Node3D movement deliberately has no building collision or rigid-body response.
	actor.position = Vector3(-2, 0, 0)
	actor.step(0.5, Vector2.RIGHT)
	expect(actor.position.x > 0, "不可吞大型建筑不排斥移动")
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		actor.position = Vector3.ZERO
		for index in 20:
			actor.step(0.1, direction)
		expect(absf(actor.position.x) <= 10.0 - actor.effective_radius + 0.0001, "X 边界不穿越")
		expect(absf(actor.position.z) <= 15.0 - actor.effective_radius + 0.0001, "Z 边界不穿越")
	actor.free()

	var initial_hole := HoleActor.new()
	initial_hole.map_size = Vector2(200, 200)
	var grown_hole := HoleActor.new()
	grown_hole.map_size = Vector2(200, 200)
	grown_hole.effective_radius = GrowthManager.RADII.back()
	initial_hole.step(1.0, Vector2.RIGHT)
	grown_hole.step(1.0, Vector2.RIGHT)
	expect_near(initial_hole.position.x, 5.2, 0.0001, "初始移动速度保持不变")
	expect(grown_hole.position.x > initial_hole.position.x * 3.0, "满级黑洞相同输入下位移超过初始三倍")
	var previous_speed := 0.0
	var speed_grows := true
	for radius in GrowthManager.RADII:
		grown_hole.effective_radius = radius
		var speed := grown_hole.current_move_speed()
		speed_grows = speed_grows and speed > previous_speed
		previous_speed = speed
	expect(speed_grows, "十九级体型的移动速度逐级提升")
	initial_hole.position = Vector3.ZERO
	initial_hole.step(1.0, Vector2.ONE)
	expect_near(initial_hole.position.length(), initial_hole.current_move_speed(), 0.0001, "对角输入归一化不会额外加速")
	initial_hole.free()
	grown_hole.free()
	var partitioned_holes: Array[HoleActor] = []
	for rate in [30, 60, 120, 144]:
		var sampled_hole := HoleActor.new()
		sampled_hole.map_size = Vector2(200, 200)
		sampled_hole.effective_radius = 2.2
		for index in rate:
			sampled_hole.step(1.0 / float(rate), Vector2(0.8, 0.6))
		partitioned_holes.append(sampled_hole)
	var baseline_hole_position := partitioned_holes[0].position
	for sampled_hole in partitioned_holes:
		expect(sampled_hole.position.distance_to(baseline_hole_position) < 0.0001, "成长后移动在不同步长划分下结果一致")
		sampled_hole.free()

	var rig := FollowCamera.new()
	rig.map_size = Vector2(20, 30)
	rig._ready()
	var downward_angle := rad_to_deg(atan2(rig.base_offset.y, Vector2(rig.base_offset.x, rig.base_offset.z).length()))
	expect(downward_angle >= 35.0 and downward_angle <= 42.0, "默认镜头降低为参考视频的斜俯视角")
	expect(rig.base_offset.x > 0.0 and rig.perspective_camera.fov <= 36.0, "斜向近景同时显示街道与建筑立面")
	var expected_forward := Vector2(-rig.base_offset.x, -rig.base_offset.z).normalized()
	expect(rig.screen_to_ground(Vector2.UP).dot(expected_forward) > 0.9999, "斜镜头下向上拖动仍朝屏幕上方移动")
	expect(is_equal_approx(rig.growth_zoom(0.65), 1.0) and is_equal_approx(rig.growth_zoom(1.0), 1.0), "前中期先让黑洞自然占据画面")
	expect_near(rig.growth_zoom(GrowthManager.RADII.back()), 3.31, 0.0001, "满级保留既定观察范围")
	rig.step(1.0 / 60.0, Vector3.ZERO, 0.38)
	var initial := rig.position
	rig.step(1.0 / 60.0, Vector3(5, 0, 0), 0.38)
	expect(rig.position.distance_to(initial) < 2.0, "平滑跟随不跳变")
	var perspective_zoom := rig.zoom
	rig.step(1.0 / 60.0, Vector3(5, 0, 0), 3.0)
	expect(rig.zoom > perspective_zoom, "成长只扩大观察范围")
	var target_zoom := rig.growth_zoom(3.0)
	expect(rig.zoom - perspective_zoom < (target_zoom - perspective_zoom) * 0.2, "成长 zoom 单帧有界而非瞬间跳变")
	for index in 120:
		rig.step(1.0 / 60.0, Vector3(100, 0, 100), 0.38)
	expect(absf(rig.position.x) <= 10.0 and absf(rig.position.z) <= 15.0, "镜头地图边缘约束")
	var edge_rig := FollowCamera.new()
	edge_rig.map_size = Vector2(20, 30)
	edge_rig._ready()
	var edge_target := Vector3(-9.62, 0, -14.62)
	edge_rig.snap(edge_target, 0.38)
	expect(edge_rig.position.distance_to(edge_target) < 4.0, "可玩地图边缘仍保持黑洞在镜头附近")
	edge_rig.step(0.1, edge_target, 0.38)
	expect(edge_rig.position.distance_to(edge_target) < 4.0, "边缘平滑跟随不会把玩家推出画面")
	edge_rig.free()
	var before := rig.zoom
	expect(rig.set_projection("orthographic"), "可切换正交")
	expect(rig.orthographic_camera.current, "正交相机激活")
	expect(rig.zoom == before, "投影不改变成长状态")
	expect(rig.set_projection("perspective") and rig.perspective_camera.current, "默认透视可恢复")
	expect(not rig.set_projection("invalid"), "拒绝未知投影")
	var logical_position := rig.position
	rig.add_shake(0.12)
	rig.step(0.05, logical_position, 0.38)
	expect(rig.position == logical_position and rig.shake_offset.length() > 0.0, "镜头震动只偏移相机不修改逻辑跟随位置")
	var normal_zoom := rig.zoom
	rig.set_finale(true)
	for tick in 10:
		rig.step(0.1, logical_position, 0.38)
	expect(rig.finale_blend == 1.0 and rig.zoom > normal_zoom * 1.4, "终点演出平滑拉远且两种投影共享观察范围")
	rig.free()
	var partitioned: Array[FollowCamera] = []
	for rate in [30, 60, 120, 144]:
		var sampled := FollowCamera.new()
		sampled.map_size = Vector2(112, 112)
		sampled._ready()
		sampled.snap(Vector3.ZERO, 0.38)
		for index in rate:
			sampled.step(1.0 / float(rate), Vector3(5, 0, 2), 3.0)
		partitioned.append(sampled)
	var baseline_position := partitioned[0].position
	var baseline_zoom := partitioned[0].zoom
	for sampled in partitioned:
		expect(sampled.position.distance_to(baseline_position) < 0.0001, "30/60/120/144Hz 指数跟随结果一致")
		expect(absf(sampled.zoom - baseline_zoom) < 0.0001, "不同渲染步长的成长 zoom 一致")
		sampled.free()
