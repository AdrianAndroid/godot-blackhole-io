extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(432, 960)
	root.content_scale_size = Vector2i(432, 960)
	var scene: CitySample = load("res://scenes/city_sample.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var districts := {}
	for model in scene.model_nodes:
		districts[model.get_meta("district_group")] = true
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/visual")
	var save_error := image.save_png("res://artifacts/visual/city_sample.png")
	var candidate_imports := _find_candidate_imports("res://assets/candidates")
	var passed := districts.size() == 4 and scene.model_nodes.size() == 24 and save_error == OK and candidate_imports.is_empty() and DisplayServer.get_name() != "headless"
	var report := {"passed": passed, "districts": districts.keys(), "models": scene.model_nodes.size(), "renderer": DisplayServer.get_name(), "candidate_imports": candidate_imports, "screenshot": "artifacts/visual/city_sample.png"}
	var output := FileAccess.open("res://artifacts/visual/city_sample.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed else 1)


func _find_candidate_imports(path: String) -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open(path)
	if directory == null:
		return found
	for file in directory.get_files():
		if file.ends_with(".import"):
			found.append(path + "/" + file)
	for child in directory.get_directories():
		found.append_array(_find_candidate_imports(path + "/" + child))
	return found
