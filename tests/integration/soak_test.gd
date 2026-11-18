extends TestCase


func run() -> void:
	var baseline_children := tree.root.get_child_count()
	var app := GameApp.new()
	tree.root.add_child(app)
	var matches: Array[Dictionary] = []
	var outcomes := {"tower": 0, "swallowed": 0, "timeout": 0}
	var retry_verified := false
	for index in 20:
		var mode: String = ["victory", "swallowed", "timeout"][index % 3]
		var seed_value := 4242 + index * 37
		app.start_session(seed_value)
		var session := app.session
		session.automatic = false
		session.audio.muted = true
		var signature: String = session.layout.signature
		var driver := AutoDriver.new()
		driver.mode = mode
		driver.avoid_all_opponents = mode != "swallowed"
		driver.failure_label = "soak_%02d_%s" % [index, mode]
		var started := Time.get_ticks_usec()
		await driver.run(session)
		var reason: String = session.result.get("reason", "none")
		var expected_reason := "tower" if mode == "victory" else mode
		if reason != expected_reason:
			FailureReporter.record(session, driver, "soak_expected_" + expected_reason, "soak_failure_%02d" % index, 0.1)
		var finished_count := 0
		for event in session.event_log:
			if event.type == "match_finished":
				finished_count += 1
		expect(session.state == GameSession.State.RESULT and reason == expected_reason and finished_count == 1, "soak %02d %s 唯一预期结局，实际 %s: %s" % [index, mode, reason, str(session.snapshot())])
		expect(session.layout.signature == signature and session.input_controller.input_vector == Vector2.ZERO and not session.input_controller.enabled and session.audio.active_players.is_empty(), "soak %02d 无随机序列、输入或音频输出残留" % index)
		if outcomes.has(reason):
			outcomes[reason] += 1
		matches.append({"index": index, "seed": seed_value, "mode": mode, "reason": reason, "ticks": driver.ticks, "duration_ms": snappedf(float(Time.get_ticks_usec() - started) / 1000.0, 0.001), "signature": signature, "result": session.result.duplicate(true)})
		var old_session: WeakRef = weakref(session)
		var old_instance_id := session.get_instance_id()
		if not retry_verified and mode == "swallowed":
			app.retry_session()
			var retry := app.session
			retry.automatic = false
			retry.audio.muted = true
			await tree.process_frame
			expect(retry.get_instance_id() != old_instance_id and retry.layout.signature == signature and retry.remaining_time == 600.0 and retry.objective.current_score == 0 and retry.audio.event_counts.is_empty(), "失败后的同图重试完整恢复: " + str([retry.layout.signature == signature, retry.remaining_time, retry.objective.current_score, retry.audio.event_counts]))
			retry_verified = true
		app.show_home()
		await tree.process_frame
		await tree.process_frame
		expect(old_session.get_ref() == null and tree.root.get_child_count() == baseline_children + 1, "soak %02d 销毁后对象和根节点回基线" % index)
	expect(matches.size() == 20 and outcomes.tower > 0 and outcomes.swallowed > 0 and outcomes.timeout > 0, "连续 20 局覆盖胜利、被吞和自然超时")
	expect(retry_verified, "soak 实际执行失败重试")
	app.queue_free()
	await tree.process_frame
	expect(tree.root.get_child_count() == baseline_children, "20 局结束应用销毁后严格回节点基线")
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output := FileAccess.open("res://artifacts/soak_matches.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed": failures.is_empty(), "matches": matches, "outcomes": outcomes, "retry_verified": retry_verified}, "\t"))
	output.close()
