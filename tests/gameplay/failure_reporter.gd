class_name FailureReporter
extends RefCounted


static func record(session: GameSession, driver: AutoDriver, reason: String, label: String, delta: float) -> Dictionary:
	DirAccess.make_dir_recursive_absolute("res://artifacts/failures")
	var recent: Array[Dictionary] = []
	var first := maxi(0, session.event_log.size() - 30)
	for index in range(first, session.event_log.size()):
		recent.append(session.event_log[index].duplicate(true))
	var report := {
		"label": label,
		"failure": reason,
		"exit_code": 1,
		"seed": session.seed_value,
		"generation_version": CityGenerator.GENERATION_VERSION,
		"signature": session.layout.signature,
		"driver_mode": driver.mode,
		"avoid_all_opponents": driver.avoid_all_opponents,
		"delta": delta,
		"input_trace": driver.input_trace.duplicate(true),
		"recent_events": recent,
		"snapshot": session.snapshot(),
		"observed_result": session.result.duplicate(true),
		"screenshot": null,
		"screenshot_status": "pending",
		"replay_command": "/usr/local/bin/godot --path . --script res://tests/gameplay/replay_failure.gd -- --report=artifacts/failures/%s.json" % label
	}
	_write_report(label, report)
	return report


static func attach_screenshot(report: Dictionary, tree: SceneTree) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		report["screenshot_status"] = "unavailable_headless"
	else:
		await RenderingServer.frame_post_draw
		var image := tree.root.get_texture().get_image()
		var path := "res://artifacts/failures/%s.png" % report.label
		var error := image.save_png(path)
		report["screenshot"] = path.trim_prefix("res://") if error == OK else null
		report["screenshot_status"] = "captured" if error == OK else "save_failed_%d" % error
	_write_report(str(report.label), report)
	return report


static func replay(report: Dictionary, tree: SceneTree) -> Dictionary:
	var session := GameSession.new()
	session.seed_value = int(report.seed)
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	session.driver_enabled = true
	var signature_matches: bool = session.layout.signature == report.signature
	for entry in report.input_trace:
		var input: Array = entry.input
		session.drive_input = Vector2(float(input[0]), float(input[1]))
		session.step(float(report.delta))
	session.drive_input = Vector2.ZERO
	var actual := session.snapshot()
	var snapshot_matches: bool = _values_equal(actual, report.snapshot)
	var failure_reproduced: bool = session.state == GameSession.State.PLAYING if report.failure == "driver_tick_limit" else _values_equal(session.result, report.observed_result)
	var replay := {
		"passed": signature_matches and snapshot_matches and failure_reproduced,
		"source": "artifacts/failures/%s.json" % report.label,
		"seed": session.seed_value,
		"generation_version": CityGenerator.GENERATION_VERSION,
		"signature_matches": signature_matches,
		"snapshot_matches": snapshot_matches,
		"failure_reproduced": failure_reproduced,
		"expected_failure": report.failure,
		"expected_snapshot": report.snapshot,
		"actual_snapshot": actual,
		"ticks": report.input_trace.size()
	}
	DirAccess.make_dir_recursive_absolute("res://artifacts/failures")
	_write_report(str(report.label) + "_replay", replay)
	session.free()
	return replay


static func _values_equal(first: Variant, second: Variant) -> bool:
	if typeof(first) in [TYPE_INT, TYPE_FLOAT] and typeof(second) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(first), float(second))
	if first is Dictionary and second is Dictionary:
		if first.size() != second.size():
			return false
		for key in first:
			if not second.has(key) or not _values_equal(first[key], second[key]):
				return false
		return true
	if first is Array and second is Array:
		if first.size() != second.size():
			return false
		for index in first.size():
			if not _values_equal(first[index], second[index]):
				return false
		return true
	return typeof(first) == typeof(second) and first == second


static func load_report(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _write_report(label: String, report: Dictionary) -> void:
	var output := FileAccess.open("res://artifacts/failures/%s.json" % label, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
