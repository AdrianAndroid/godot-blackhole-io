extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows: Array[Dictionary] = []
	for district in ["commercial", "suburban", "industrial", "roads", "vehicles", "characters"]:
		var path: String = "res://assets/game/models/" + district
		for file in DirAccess.get_files_at(path):
			if not file.ends_with(".glb") and not file.ends_with(".fbx"):
				continue
			var scene: PackedScene = load(path + "/" + file)
			if scene == null:
				rows.append({"model": file, "error": "load_failed"})
				continue
			var instance := scene.instantiate()
			var bounds := _bounds(instance, Transform3D.IDENTITY)
			rows.append({
				"model": district + "/" + file,
				"min": [bounds.position.x, bounds.position.y, bounds.position.z],
				"size": [bounds.size.x, bounds.size.y, bounds.size.z],
				"animations": _animation_names(instance),
			})
			instance.free()
	var output := FileAccess.open("res://artifacts/model_bounds.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(rows, "\t"))
	output.close()
	print(JSON.stringify(rows))
	quit()


func _animation_names(node: Node) -> Array[String]:
	var names: Array[String] = []
	if node is AnimationPlayer:
		for animation in node.get_animation_list():
			names.append(str(animation))
	for child in node.get_children():
		names.append_array(_animation_names(child))
	return names


func _bounds(node: Node, parent_transform: Transform3D) -> AABB:
	var current := parent_transform
	if node is Node3D:
		current = parent_transform * node.transform
	var result := AABB()
	var initialized := false
	if node is MeshInstance3D:
		var local: AABB = node.get_aabb()
		for corner in 8:
			var point := local.position + Vector3(
				local.size.x if corner & 1 else 0.0,
				local.size.y if corner & 2 else 0.0,
				local.size.z if corner & 4 else 0.0
			)
			point = current * point
			if not initialized:
				result = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				result = result.expand(point)
	for child in node.get_children():
		var child_bounds := _bounds(child, current)
		if child_bounds.size == Vector3.ZERO:
			continue
		result = child_bounds if not initialized else result.merge(child_bounds)
		initialized = true
	return result
