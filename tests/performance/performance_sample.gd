extends SceneTree

var failures: Array[String] = []
var phases: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(432, 960)
	root.content_scale_size = Vector2i(432, 960)
	DirAccess.make_dir_recursive_absolute("res://artifacts/performance")
	if DisplayServer.get_name() == "headless":
		failures.append("性能渲染采样不得以 headless 替代")
	var session := GameSession.new()
	session.seed_value = 20261115
	root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	session.driver_enabled = true
	var driver := AutoDriver.new()
	driver.avoid_all_opponents = true
	var initial_objects := session.spawn_manager.objects.size()
	var initial_opponents := session.living_opponents()
	if initial_opponents != 4:
		failures.append("性能场景必须包含四个对手")
	phases.append(await _sample_phase(session, "typical_city", 120, driver))
	phases.append(await _sample_phase(session, "continuous_swallowing", 240, driver))
	var density_root := Node3D.new()
	density_root.name = "PerformanceDensity"
	session.add_child(density_root)
	var registry := ModelRegistry.new()
	var density_models := 0
	for z in 12:
		for x in 12:
			var model_id: String = ["commercial_a", "house_a", "industrial_a"][(x + z) % 3]
			var model := registry.instantiate(model_id)
			model.position = session.player.position + Vector3((x - 5.5) * 1.4, 0, (z - 5.5) * 1.4 - 8.0)
			model.rotation_degrees.y = float((x * 37 + z * 19) % 360)
			density_root.add_child(model)
			density_models += 1
	session.camera_rig.step(1.0, session.player.position, session.player.effective_radius)
	var dense := await _sample_phase(session, "high_density", 120, driver)
	dense["additional_building_models"] = density_models
	phases.append(dense)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/performance/high_density.png")
	for phase in phases:
		if phase.samples != [120, 240, 120][phases.find(phase)]:
			failures.append(phase.name + " 样本数量不完整")
		if phase.frame_time_ms.p50 <= 0.0 or phase.rendering.peak_draw_calls <= 0:
			failures.append(phase.name + " 缺少有效帧时间或渲染统计")
	var report := {
		"passed": failures.is_empty(),
		"purpose": "画质优先，仅报告采样；不设置 30/60 FPS 通过门槛",
		"renderer": DisplayServer.get_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"device": RenderingServer.get_video_adapter_name(),
		"viewport": [432, 960],
		"seed": session.seed_value,
		"initial_ordinary_objects": initial_objects,
		"opponents": initial_opponents,
		"engine": Engine.get_version_info().string,
		"os_memory": OS.get_memory_info(),
		"failures": failures,
		"phases": phases
	}
	var output := FileAccess.open("res://artifacts/performance/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify({"passed": report.passed, "failures": failures, "phases": phases.size(), "report": "artifacts/performance/report.json"}))
	session.free()
	quit(0 if report.passed else 1)


func _sample_phase(session: GameSession, phase_name: String, frame_count: int, driver: AutoDriver) -> Dictionary:
	var samples: Array[float] = []
	var peak_draw_calls := 0
	var peak_primitives := 0
	var peak_nodes := 0
	var peak_static_memory := 0.0
	var settled_start := _settled_count(session)
	var previous := Time.get_ticks_usec()
	for frame in frame_count:
		session.drive_input = driver.choose_input(session)
		session.step(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		peak_draw_calls = maxi(peak_draw_calls, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		peak_primitives = maxi(peak_primitives, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
		peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		peak_static_memory = maxf(peak_static_memory, float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0)
	session.drive_input = Vector2.ZERO
	var sorted := samples.duplicate()
	sorted.sort()
	return {
		"name": phase_name,
		"samples": samples.size(),
		"frame_time_ms": {"min": snappedf(sorted[0], 0.001), "p50": snappedf(_percentile(sorted, 0.50), 0.001), "p95": snappedf(_percentile(sorted, 0.95), 0.001), "p99": snappedf(_percentile(sorted, 0.99), 0.001), "max": snappedf(sorted[-1], 0.001), "mean": snappedf(_mean(samples), 0.001)},
		"rendering": {"peak_draw_calls": peak_draw_calls, "peak_primitives": peak_primitives, "last_objects": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))},
		"memory": {"peak_static_mb": snappedf(peak_static_memory, 0.01), "static_max_mb": snappedf(float(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)) / 1048576.0, 0.01)},
		"nodes": {"peak": peak_nodes, "final": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))},
		"gameplay": {"objects_remaining": session.spawn_manager.objects.size(), "living_opponents": session.living_opponents(), "settled_during_phase": _settled_count(session) - settled_start, "remaining": snappedf(session.remaining_time, 0.001)}
	}


func _settled_count(session: GameSession) -> int:
	var count := 0
	for event in session.event_log:
		if event.type == "object_settled":
			count += 1
	return count


func _percentile(sorted: Array, quantile: float) -> float:
	var index := clampi(ceili((sorted.size() - 1) * quantile), 0, sorted.size() - 1)
	return float(sorted[index])


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / values.size()
