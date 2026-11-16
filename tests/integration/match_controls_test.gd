extends TestCase


func run() -> void:
	var perspective := await _controlled_match(8242, "perspective")
	var orthographic := await _controlled_match(8242, "orthographic")
	var first: GameSession = perspective.session
	var second: GameSession = orthographic.session
	expect(perspective.pause_frozen and orthographic.pause_frozen, "整局暂停恢复冻结所有逻辑数值")
	expect(perspective.signature_stable and orthographic.signature_stable, "整局操作不改变布局随机序列")
	expect(first.camera_rig.projection != second.camera_rig.projection, "两个完整对局保持不同投影")
	expect(JSON.stringify(first.snapshot()) == JSON.stringify(second.snapshot()), "两种投影产生完全相同的移动吞噬与结算快照")
	expect(first.result.get("victory") == true and second.result.get("victory") == true, "组合操作后仍通过真实高塔完成胜利")
	expect(first.input_controller.input_vector == Vector2.ZERO and second.input_controller.input_vector == Vector2.ZERO, "鼠标触摸切换与取消后无残留输入")
	expect(_finished_count(first) == 1 and _finished_count(second) == 1, "组合整局各只有唯一结果")
	expect(first.objective.current_score == second.objective.current_score and first.objective.coins == second.objective.coins, "投影及输入切换不改变目标分和金币语义")
	first.free()
	second.free()
	await _multi_knockdown_match()


func _controlled_match(seed_value: int, projection: String) -> Dictionary:
	var session := _session(seed_value)
	session.camera_rig.set_projection(projection)
	var signature: String = session.layout.signature
	var driver := AutoDriver.new()
	driver.avoid_all_opponents = true
	var pause_frozen := false
	var ticks := 0
	while session.state == GameSession.State.PLAYING and ticks < 6000:
		if ticks == 40:
			session.pause()
			var frozen := str(session.snapshot())
			session.step(2.0)
			pause_frozen = str(session.snapshot()) == frozen
			session.resume()
		if ticks == 160 or ticks == 320:
			session.toggle_projection()
		if ticks >= 100 and ticks < 105:
			if ticks == 100:
				session.driver_enabled = false
				_mouse(session, true, Vector2(180, 720))
			_mouse_motion(session, Vector2(245, 720))
			session.step(0.1)
		elif ticks >= 105 and ticks < 110:
			if ticks == 105:
				_mouse(session, false, Vector2(245, 720))
				_touch(session, 0, true, Vector2(180, 720), false)
			_touch(session, 0, true, Vector2(245, 720), true)
			session.step(0.1)
		else:
			if ticks == 110:
				_touch(session, 0, false, Vector2(245, 720), false, true)
				session.driver_enabled = true
			session.driver_enabled = true
			session.drive_input = driver.choose_input(session)
			session.step(0.1)
		ticks += 1
	session.drive_input = Vector2.ZERO
	if session.state != GameSession.State.RESULT:
		FailureReporter.record(session, driver, "controlled_match_incomplete", "controlled_" + projection, 0.1)
	return {"session": session, "pause_frozen": pause_frozen, "signature_stable": signature == session.layout.signature}


func _multi_knockdown_match() -> void:
	var session := _session(8243)
	var driver := AutoDriver.new()
	driver.avoid_all_opponents = true
	for index in 100:
		session.drive_input = driver.choose_input(session)
		session.step(0.1)
	session.drive_input = Vector2.ZERO
	session.growth.add_experience(36)
	session.player.effective_radius = session.growth.radius
	session.opponents[0].position = session.player.position
	session.opponents[1].position = session.player.position
	var score_before: int = session.objective.current_score
	var coins_before: int = session.objective.coins
	var ordinary := {"score": 0, "coins": 0}
	session.swallow_manager.completed.connect(func(event: Dictionary) -> void:
		if event.kind == "normal":
			ordinary.score += int(event.score)
			ordinary.coins += int(event.coins)
	)
	session.step(0.01)
	session.step(1.0)
	expect(session.objective.knockdowns == 2 and session.objective.multi_knockdown == 2, "完整对局中实际触发二重击倒")
	expect(session.objective.current_score == score_before + 120 + int(ordinary.score) and session.objective.coins == coins_before + int(ordinary.coins), "多重击倒增加既定目标分，合法同帧普通吞噬独立结算: score %d -> %d, ordinary=%d, coins %d -> %d, ordinary_coins=%d" % [score_before, session.objective.current_score, int(ordinary.score), coins_before, session.objective.coins, int(ordinary.coins)])
	driver.run(session)
	expect(session.state == GameSession.State.RESULT and _finished_count(session) == 1, "多重击倒后的完整对局唯一结束")
	expect(session.layout.signature == session.generator.generate(8243).signature, "多重击倒不消耗或改变城市随机流")
	session.free()


func _finished_count(session: GameSession) -> int:
	var count := 0
	for event in session.event_log:
		if event.type == "match_finished":
			count += 1
	return count


func _mouse(session: GameSession, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	session.input_controller.handle_event(event)


func _mouse_motion(session: GameSession, position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	session.input_controller.handle_event(event)


func _touch(session: GameSession, id: int, pressed: bool, position: Vector2, drag: bool, canceled: bool = false) -> void:
	if drag:
		var event := InputEventScreenDrag.new()
		event.index = id
		event.position = position
		session.input_controller.handle_event(event)
		return
	var event := InputEventScreenTouch.new()
	event.index = id
	event.pressed = pressed
	event.position = position
	event.canceled = canceled
	session.input_controller.handle_event(event)


func _session(seed_value: int) -> GameSession:
	var session := GameSession.new()
	session.seed_value = seed_value
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	return session
