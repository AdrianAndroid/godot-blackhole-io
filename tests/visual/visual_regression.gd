extends SceneTree

const CHECKPOINTS: Array[String] = ["home", "initial", "growing", "sinking", "max_level", "multi_knockdown", "tower", "victory", "defeat", "input_edge", "occlusion", "water_hole"]
var update_baselines: bool = false
var reports: Array[Dictionary] = []
var failures: Array[String] = []
var baseline_hashes_before: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	update_baselines = "--update-baselines" in OS.get_cmdline_user_args()
	root.size = Vector2i(432, 960)
	root.content_scale_size = Vector2i(432, 960)
	DirAccess.make_dir_recursive_absolute("res://artifacts/visual/regression")
	DirAccess.make_dir_recursive_absolute("res://artifacts/visual/baseline_updates")
	DirAccess.make_dir_recursive_absolute("res://tests/baselines")
	if DisplayServer.get_name() == "headless":
		failures.append("真实图形回归不得以 headless 替代")
	if not update_baselines:
		for checkpoint in CHECKPOINTS:
			for projection in ["perspective", "orthographic"]:
				var path := _baseline_path(checkpoint, projection)
				if not FileAccess.file_exists(path):
					failures.append("缺少基线: " + path)
				else:
					baseline_hashes_before[path] = _file_hash(path)
	for checkpoint in CHECKPOINTS:
		if checkpoint == "home":
			await _capture_home(checkpoint)
		else:
			await _capture_session(checkpoint)
	var completed := {}
	for report in reports:
		completed[report.checkpoint] = true
	for checkpoint in CHECKPOINTS:
		if not completed.has(checkpoint):
			failures.append("缺少检查点: " + checkpoint)
	if not update_baselines:
		for path in baseline_hashes_before:
			if _file_hash(path) != baseline_hashes_before[path]:
				failures.append("普通测试覆盖了基线: " + path)
	var passed := failures.is_empty()
	var output_data := {"passed": passed, "renderer": DisplayServer.get_name(), "viewport": [432, 960], "update_baselines": update_baselines, "failures": failures, "checkpoints": reports}
	var output := FileAccess.open("res://artifacts/visual/regression/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(output_data, "\t"))
	output.close()
	if update_baselines:
		var history := FileAccess.open("res://artifacts/visual/baseline_updates/report.json", FileAccess.WRITE)
		history.store_string(JSON.stringify({"date": Time.get_datetime_string_from_system(), "explicit": true, "checkpoints": reports}, "\t"))
		history.close()
	print(JSON.stringify({"passed": passed, "failures": failures, "checkpoints": reports.size(), "update_baselines": update_baselines}))
	quit(0 if passed else 1)


func _capture_home(checkpoint: String) -> void:
	var home := HomeScreen.new()
	root.add_child(home)
	await _settle()
	await _capture_modes(checkpoint, null, {})
	home.queue_free()
	await process_frame


func _capture_session(checkpoint: String) -> void:
	var session := GameSession.new()
	session.seed_value = 20261115
	root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	_prepare_checkpoint(checkpoint, session)
	_freeze_holes(session)
	session.camera_rig.set_projection("perspective")
	await _settle()
	var snapshot := session.snapshot()
	await _capture_modes(checkpoint, session, snapshot)
	session.queue_free()
	await process_frame


func _prepare_checkpoint(checkpoint: String, session: GameSession) -> void:
	match checkpoint:
		"growing":
			var driver := AutoDriver.new()
			driver.avoid_all_opponents = true
			session.driver_enabled = true
			var ticks := 0
			while session.growth.level < 5 and session.state == GameSession.State.PLAYING and ticks < 1200:
				session.drive_input = driver.choose_input(session)
				session.step(0.1)
				ticks += 1
			session.drive_input = Vector2.ZERO
		"sinking":
			var target := _first_eligible(session)
			session.player.position = target.position
			session.camera_rig.step(1.0, session.player.position, session.player.effective_radius)
			session.step(0.01)
			session.step(0.18)
		"max_level":
			session.growth.add_experience(10000)
			session.player.effective_radius = session.growth.radius
			session.hud.show_message("最大体型 · 继续吞噬得分")
			session._update_hud()
		"multi_knockdown":
			session.player.effective_radius = 1.0
			session.opponents[0].position = session.player.position
			session.opponents[1].position = session.player.position
			session.step(0.01)
			session.step(1.0)
		"tower":
			_unlock(session)
			session.player.position = session.tower.position + Vector3(0, 0, 8)
			session.camera_rig.step(1.0, session.player.position, session.player.effective_radius)
			session._update_hud()
		"victory":
			_unlock(session)
			session.player.position = session.tower.position
			session.step(0.01)
			session.step(1.3)
		"defeat":
			session.opponents[3].position = session.player.position
			session.step(0.01)
			session.step(1.0)
		"input_edge":
			session.player.position = Vector3(-39.5, 0, -39.5)
			session.camera_rig.step(1.0, session.player.position, session.player.effective_radius)
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = Vector2(100, 780)
			session.input_controller.handle_event(press)
			var drag := InputEventMouseMotion.new()
			drag.position = Vector2(150, 738)
			session.input_controller.handle_event(drag)
		"occlusion":
			for object in session.spawn_manager.objects.values():
				if object.footprint_radius > session.player.effective_radius * 2.0:
					session.player.position = object.position
					session.camera_rig.step(1.0, session.player.position, session.player.effective_radius)
					if object.state != Swallowable.State.IDLE:
						failures.append("不可吞建筑被错误吞噬")
					break
		"water_hole":
			session.player.position = Vector3(34, 0, 0)
			session.player.effective_radius = 1.2
			session.camera_rig.step(1.0, session.player.position, session.player.effective_radius)


func _capture_modes(checkpoint: String, session: GameSession, before: Dictionary) -> void:
	var perspective := await _capture_image(checkpoint + "_perspective")
	var entry := {"checkpoint": checkpoint, "perspective": perspective, "snapshot_before": before}
	if session != null:
		session.camera_rig.set_projection("orthographic")
		await _settle()
		var after := session.snapshot()
		if str(before) != str(after):
			failures.append(checkpoint + " 投影切换改变逻辑快照")
	var orthographic := await _capture_image(checkpoint + "_orthographic")
	entry["orthographic"] = orthographic
	if session != null:
		entry["snapshot_after"] = session.snapshot()
		for rect in session.hud.safe_rects:
			if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > 432 or rect.end.y > 960:
				failures.append(checkpoint + " HUD 超出安全区")
	reports.append(entry)


func _capture_image(label: String) -> Dictionary:
	# A newly hidden mesh can leave a stale directional-shadow frame. Compare
	# complete rendered frames so neither a cold run nor a baseline update can
	# capture that transient instead of the deterministic checkpoint.
	var image: Image
	var previous_frame := PackedByteArray()
	var stable := false
	var rendered_frames := 0
	for attempt in 16:
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		rendered_frames += 1
		var current_frame := image.get_data()
		if not previous_frame.is_empty() and current_frame == previous_frame:
			stable = true
			break
		previous_frame = current_frame
	if not stable:
		failures.append(label + " 连续渲染帧未稳定")
	if image.get_width() != 432 or image.get_height() != 960:
		failures.append(label + " 截图尺寸错误")
	var actual := "res://artifacts/visual/regression/" + label + ".png"
	image.save_png(actual)
	var baseline := "res://tests/baselines/" + label + ".png"
	var result := {"actual": actual.trim_prefix("res://"), "baseline": baseline.trim_prefix("res://"), "rendered_frames": rendered_frames}
	if update_baselines:
		if FileAccess.file_exists(baseline):
			var previous := Image.load_from_file(baseline)
			previous.save_png("res://artifacts/visual/baseline_updates/" + label + "_before.png")
		image.save_png("res://artifacts/visual/baseline_updates/" + label + "_after.png")
		image.save_png(baseline)
		result["updated"] = true
	else:
		if FileAccess.file_exists(baseline):
			var expected := Image.load_from_file(baseline)
			var comparison := _compare(expected, image, label)
			result["comparison"] = comparison
			if comparison.fraction > 0.01:
				failures.append(label + " 像素差异超过 1%")
	return result


func _compare(expected: Image, actual: Image, label: String) -> Dictionary:
	var diff := Image.create(432, 960, false, Image.FORMAT_RGBA8)
	var changed := 0
	if expected.get_size() != actual.get_size():
		return {"fraction": 1.0, "changed": 414720, "error": "尺寸不同"}
	for y in 960:
		for x in 432:
			var a := expected.get_pixel(x, y)
			var b := actual.get_pixel(x, y)
			var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if delta > 0.04:
				changed += 1
				diff.set_pixel(x, y, Color(1, 0.05, 0.2))
			else:
				diff.set_pixel(x, y, Color(b.r * 0.22, b.g * 0.22, b.b * 0.22))
	var path := "res://artifacts/visual/regression/" + label + "_diff.png"
	diff.save_png(path)
	return {"changed": changed, "fraction": float(changed) / 414720.0, "channel_tolerance": 0.04, "allowed_fraction": 0.01, "diff": path.trim_prefix("res://")}


func _first_eligible(session: GameSession) -> Swallowable:
	for object in session.spawn_manager.objects.values():
		if object.footprint_radius < session.player.effective_radius:
			return object
	return null


func _unlock(session: GameSession) -> void:
	for placement in session.layout.objects:
		var entry: Dictionary = session.generator._catalog_entry(placement.model_id)
		session.objective.settle({"object_id": placement.id, "kind": "normal", "score": entry.score, "coins": entry.coins, "xp": 0})
		if session.objective.tower_unlocked:
			break


func _freeze_holes(session: GameSession) -> void:
	session.player.visual.animation_time = 2.0
	for opponent in session.opponents:
		opponent.actor.visual.animation_time = 2.0
	if session.player_death_target != null:
		(session.player_death_target.model_root as HoleVisual).animation_time = 2.0


func _settle() -> void:
	await process_frame
	await process_frame


func _baseline_path(checkpoint: String, projection: String) -> String:
	return "res://tests/baselines/" + checkpoint + "_" + projection + ".png"


func _file_hash(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
