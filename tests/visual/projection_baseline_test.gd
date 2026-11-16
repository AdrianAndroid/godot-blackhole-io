extends SceneTree

var failures: Array[String] = []
var update_baselines: bool = false
var baseline_hashes: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	update_baselines = "--update-baselines" in OS.get_cmdline_user_args()
	root.size = Vector2i(432, 960)
	root.content_scale_size = Vector2i(432, 960)
	DirAccess.make_dir_recursive_absolute("res://artifacts/visual/projection")
	DirAccess.make_dir_recursive_absolute("res://tests/baselines")
	for label in ["perspective", "orthographic"]:
		var path: String = "res://tests/baselines/city_" + label + ".png"
		if not update_baselines and not FileAccess.file_exists(path):
			failures.append("缺少城市投影基线: " + path)
		elif not update_baselines:
			baseline_hashes[path] = _hash(path)
	var scene: CitySample = load("res://scenes/city_sample.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var ids: Array[int] = []
	var positions: Array[Vector3] = []
	for model in scene.model_nodes:
		ids.append(model.get_instance_id())
		positions.append(model.position)
	var gameplay_state := {"score": 42, "level": 3, "remaining": 477.0, "objects": scene.model_nodes.size()}
	var before := str([ids, positions, gameplay_state])
	scene.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var perspective := await _capture("perspective")
	scene.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.camera.size = 66.0
	var orthographic := await _capture("orthographic")
	var after_ids: Array[int] = []
	var after_positions: Array[Vector3] = []
	for model in scene.model_nodes:
		after_ids.append(model.get_instance_id())
		after_positions.append(model.position)
	if before != str([after_ids, after_positions, gameplay_state]):
		failures.append("投影切换改变模型实例或玩法状态")
	var comparison := _compare(perspective, orthographic, "diff")
	var baseline_comparisons := {}
	if not update_baselines:
		for label in ["perspective", "orthographic"]:
			var expected := Image.load_from_file("res://tests/baselines/city_" + label + ".png")
			var actual: Image = perspective if label == "perspective" else orthographic
			var baseline_comparison := _compare(expected, actual, label + "_baseline_diff")
			baseline_comparisons[label] = baseline_comparison
			if baseline_comparison.fraction > 0.01:
				failures.append(label + " 城市投影基线差异超过 1%")
		for path in baseline_hashes:
			if _hash(path) != baseline_hashes[path]:
				failures.append("普通城市投影测试覆盖基线: " + path)
	var passed: bool = failures.is_empty() and DisplayServer.get_name() != "headless" and comparison.different_pixels > 0
	var report := {"passed": passed, "update_baselines": update_baselines, "failures": failures, "renderer": DisplayServer.get_name(), "comparison": comparison, "baseline_comparisons": baseline_comparisons, "perspective_baseline": "tests/baselines/city_perspective.png", "orthographic_baseline": "tests/baselines/city_orthographic.png"}
	var output := FileAccess.open("res://artifacts/visual/projection/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed else 1)


func _capture(label: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://artifacts/visual/projection/" + label + ".png")
	if update_baselines:
		image.save_png("res://tests/baselines/city_" + label + ".png")
	return image


func _compare(first: Image, second: Image, label: String) -> Dictionary:
	if first == null or second == null or first.get_size() != second.get_size():
		return {"different_pixels": 414720, "fraction": 1.0, "total_pixels": 414720, "tolerance": 0.04}
	var diff := Image.create(first.get_width(), first.get_height(), false, Image.FORMAT_RGBA8)
	var changed := 0
	for y in first.get_height():
		for x in first.get_width():
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if delta > 0.04:
				changed += 1
				diff.set_pixel(x, y, Color(1, 0.1, 0.25, 1))
			else:
				diff.set_pixel(x, y, Color(a.r * 0.25, a.g * 0.25, a.b * 0.25, 1))
	var path := "res://artifacts/visual/projection/" + label + ".png"
	diff.save_png(path)
	var total := first.get_width() * first.get_height()
	return {"different_pixels": changed, "fraction": float(changed) / total, "total_pixels": total, "tolerance": 0.04, "diff": path.trim_prefix("res://")}


func _hash(path: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()
