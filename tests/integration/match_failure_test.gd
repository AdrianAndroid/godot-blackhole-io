extends TestCase


func run() -> void:
	var swallowed := _session(7311)
	var pursuit := AutoDriver.new()
	pursuit.mode = "swallowed"
	pursuit.run(swallowed)
	if swallowed.result.get("reason") != "swallowed":
		FailureReporter.record(swallowed, pursuit, "expected_swallowed", "match_swallowed_failure", 0.1)
	expect(swallowed.state == GameSession.State.RESULT and swallowed.result.get("reason") == "swallowed", "大型对手通过真实接触和下沉完成整局失败: " + str(swallowed.snapshot()))
	expect(swallowed.player_death_target != null and swallowed.player_death_target.state == Swallowable.State.SETTLED, "失败路径实际完成玩家下沉")
	expect(swallowed.result.get("score") == swallowed.objective.current_score and swallowed.result.get("coins") == swallowed.objective.coins, "被吞前合法奖励与失败结算保持一致")
	expect(_finished_count(swallowed) == 1, "被吞路径唯一结局")
	var swallowed_frozen := str(swallowed.snapshot())
	swallowed._completed_events.append({"object_id": 777777, "kind": "normal", "score": 99, "coins": 9, "xp": 99})
	swallowed._process_completed_events()
	swallowed.step(10.0)
	expect(str(swallowed.snapshot()) == swallowed_frozen, "被吞结束后奖励与状态冻结")
	swallowed.free()

	var timeout := _session(7312)
	var survivor := AutoDriver.new()
	survivor.mode = "timeout"
	survivor.avoid_all_opponents = true
	survivor.run(timeout)
	if timeout.result.get("reason") != "timeout" and not survivor.failure_report.is_empty():
		survivor.failure_report = FailureReporter.record(timeout, survivor, "expected_timeout", "match_timeout_failure", 0.1)
	expect(timeout.state == GameSession.State.RESULT and timeout.result.get("reason") == "timeout", "真实移动避让并自然耗尽 600 秒: " + str(timeout.snapshot()))
	expect(timeout.remaining_time == 0.0 and timeout.objective.match_time >= 600.0, "自然倒计时完成完整十分钟")
	expect(timeout.objective.current_score == 0 and timeout.objective.knockdowns == 0, "超时不借助直接分数或结局设置")
	expect(_finished_count(timeout) == 1, "超时路径唯一结局")
	var timeout_frozen := str(timeout.snapshot())
	timeout._completed_events.append({"object_id": 777778, "kind": "normal", "score": 99, "coins": 9, "xp": 99})
	timeout._process_completed_events()
	timeout.step(10.0)
	expect(str(timeout.snapshot()) == timeout_frozen, "超时结束后奖励与状态冻结")
	timeout.free()


func _finished_count(session: GameSession) -> int:
	var count := 0
	for event in session.event_log:
		if event.type == "match_finished":
			count += 1
	return count


func _session(seed_value: int) -> GameSession:
	var session := GameSession.new()
	session.seed_value = seed_value
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	return session
