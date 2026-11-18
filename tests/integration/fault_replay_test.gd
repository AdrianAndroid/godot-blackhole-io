extends TestCase


func run() -> void:
	var session := GameSession.new()
	session.seed_value = 4242
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	var driver := AutoDriver.new()
	driver.avoid_all_opponents = true
	driver.failure_label = "self_test_tick_limit"
	await driver.run(session, 0.1, 3)
	var report := driver.failure_report
	expect(not report.is_empty(), "有界驱动失败自动保存报告")
	expect(report.get("seed") == 4242 and report.get("generation_version") == CityGenerator.GENERATION_VERSION, "报告包含种子和生成版本")
	expect(report.get("signature") == session.layout.signature, "报告包含布局签名")
	expect(report.get("input_trace", []).size() == 3 and report.get("exit_code") == 1, "报告包含逐 tick 输入和失败退出码")
	expect(report.get("recent_events", []).size() > 0 and not report.get("snapshot", {}).is_empty(), "报告包含最近事件和逻辑快照")
	await FailureReporter.attach_screenshot(report, tree)
	if DisplayServer.get_name() == "headless":
		expect(report.screenshot_status == "unavailable_headless", "headless 明确标记无截图")
	else:
		expect(report.screenshot_status == "captured" and FileAccess.file_exists(report.screenshot), "真实图形失败报告保存截图")
	var replay := FailureReporter.replay(report, tree)
	expect(replay.passed, "独立输入轨迹重放复现同一故障")
	expect(replay.signature_matches and replay.snapshot_matches, "重放布局及最终逻辑快照一致")
	expect(replay.failure_reproduced and replay.ticks == 3, "重放复现 driver_tick_limit 而非直接调用结局")
	session.free()
