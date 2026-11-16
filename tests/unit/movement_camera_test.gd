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

	var rig := FollowCamera.new()
	rig.map_size = Vector2(20, 30)
	rig._ready()
	rig.step(1.0 / 60.0, Vector3.ZERO, 0.38)
	var initial := rig.position
	rig.step(1.0 / 60.0, Vector3(5, 0, 0), 0.38)
	expect(rig.position.distance_to(initial) < 2.0, "平滑跟随不跳变")
	var perspective_zoom := rig.zoom
	rig.step(1.0 / 60.0, Vector3(5, 0, 0), 3.0)
	expect(rig.zoom > perspective_zoom, "成长只扩大观察范围")
	for index in 120:
		rig.step(1.0 / 60.0, Vector3(100, 0, 100), 0.38)
	expect(absf(rig.position.x) <= 10.0 and absf(rig.position.z) <= 15.0, "镜头地图边缘约束")
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
	rig.free()
