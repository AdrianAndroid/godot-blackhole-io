extends TestCase


func run() -> void:
	var session := GameSession.new()
	session.seed_value = 4242
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	var driver := AutoDriver.new()
	driver.avoid_all_opponents = true
	var result := driver.run(session)
	expect(session.state == GameSession.State.RESULT, "自动整局到达唯一结算: " + str(session.snapshot()))
	expect(result.get("victory") == true, "实际移动吞噬成长并吞高塔获胜: " + str(session.snapshot()))
	expect(session.growth.level > 1, "自动对局实际成长")
	expect(session.objective.knockdowns == 0, "只靠普通建筑零击倒完成")
	var types := {}
	for event in session.event_log:
		types[event.type] = true
	for required in ["object_settled", "level_up", "tower_spawned", "match_finished"]:
		expect(types.has(required), "整局事件包含 " + required)
	expect(session.tower != null and session.tower.state == Swallowable.State.SETTLED, "高塔实际完全消失")
	expect(driver.ticks <= 6000 and session.remaining_time >= 0.0, "完整 10 分钟加速驱动有界")
	var frozen := str(session.snapshot())
	session.step(10.0)
	expect(str(session.snapshot()) == frozen, "胜利后奖励冻结")
	session.free()
