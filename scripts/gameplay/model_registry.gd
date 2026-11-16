class_name ModelRegistry
extends RefCounted

var entries: Dictionary = {}
var load_errors: Array[String] = []


func _init(catalog_path: String = "res://config/model_catalog.json") -> void:
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		load_errors.append("目录不存在: " + catalog_path)
		return
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.get("models") is Array:
		load_errors.append("目录格式无效")
		return
	for entry in data.models:
		if entry is Dictionary and entry.has("id"):
			entries[entry.id] = entry
		else:
			load_errors.append("模型项缺少 ID")


func get_entry(model_id: String) -> Dictionary:
	return entries.get(model_id, {})


func instantiate(model_id: String, variant: String = "") -> Node3D:
	var entry := get_entry(model_id)
	if entry.is_empty():
		return null
	var instance: Node3D
	if str(entry.path) == "procedural://duck":
		instance = DuckVisual.new()
	else:
		var packed: PackedScene = load(entry.path)
		if packed == null:
			return null
		instance = packed.instantiate() as Node3D
	instance.scale = Vector3.ONE * float(entry.scale)
	instance.position.y = float(entry.ground_offset)
	instance.rotation_degrees.y = float(entry.get("rotation_y", 0.0))
	instance.set_meta("model_id", model_id)
	if variant != "" and entry.district == "commercial":
		_apply_variant(instance, variant)
	if model_id == "pedestrian":
		_configure_pedestrian(instance, variant)
	return instance


func validate(check_visual: bool = true) -> Array[String]:
	var errors: Array[String] = load_errors.duplicate()
	for model_id in entries:
		var entry: Dictionary = entries[model_id]
		for field in ["path", "district", "scale", "ground_offset", "rotation_y", "footprint_radius", "xp", "score", "coins", "tier", "swallowable"]:
			if not entry.has(field):
				errors.append("%s 缺少字段 %s" % [model_id, field])
		if errors.size() > 0 and not entry.has("path"):
			continue
		if not str(entry.path).begins_with("procedural://") and not ResourceLoader.exists(str(entry.path)):
			errors.append(model_id + " 资源不存在")
		if float(entry.get("scale", 0.0)) <= 0.0:
			errors.append(model_id + " 缩放必须为正")
		if bool(entry.get("swallowable", false)) and float(entry.get("footprint_radius", 0.0)) <= 0.0:
			errors.append(model_id + " 可吞模型半径必须为正")
		for field in ["xp", "score", "coins", "tier"]:
			if int(entry.get(field, -1)) < 0:
				errors.append("%s %s 不得为负" % [model_id, field])
		if check_visual and (str(entry.path).begins_with("procedural://") or ResourceLoader.exists(str(entry.path))):
			var instance := instantiate(model_id)
			if instance == null:
				errors.append(model_id + " 无法实例化")
				continue
			var bounds := measure_bounds(instance, Transform3D.IDENTITY)
			if not _valid_bounds(bounds):
				errors.append(model_id + " 视觉包围盒无效")
			elif absf(bounds.position.y - float(entry.ground_offset)) > 0.05:
				errors.append(model_id + " 模型未落在地面原点")
			instance.free()
	return errors


func measure_bounds(node: Node, parent_transform: Transform3D) -> AABB:
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
		var child_bounds := measure_bounds(child, current)
		if child_bounds.size == Vector3.ZERO:
			continue
		result = child_bounds if not initialized else result.merge(child_bounds)
		initialized = true
	return result


func _valid_bounds(bounds: AABB) -> bool:
	return bounds.size.is_finite() and bounds.position.is_finite() and bounds.size.x > 0.0 and bounds.size.y > 0.0 and bounds.size.z > 0.0


func _apply_variant(node: Node, variant: String) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var texture_path := "res://assets/game/models/commercial/Textures/variation-%s.png" % variant
		if ResourceLoader.exists(texture_path):
			for surface in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(surface)
				if material is StandardMaterial3D:
					var copy := material.duplicate() as StandardMaterial3D
					copy.albedo_texture = load(texture_path)
					node.set_surface_override_material(surface, copy)
	for child in node.get_children():
		_apply_variant(child, variant)


func _configure_pedestrian(instance: Node3D, variant: String) -> void:
	var skins := ["cyborgFemaleA", "criminalMaleA", "skaterFemaleA", "skaterMaleA"]
	var skin_index := clampi(int(variant) if variant.is_valid_int() else 0, 0, skins.size() - 1)
	var texture: Texture2D = load("res://assets/game/models/characters/Skins/" + skins[skin_index] + ".png")
	_apply_skin(instance, texture)
	var run_scene: PackedScene = load("res://assets/game/models/characters/run.fbx")
	var run_instance := run_scene.instantiate()
	var source := _find_animation_player(run_instance)
	var player := AnimationPlayer.new()
	player.name = "RunAnimation"
	player.playback_process_mode = AnimationPlayer.ANIMATION_PROCESS_MANUAL
	instance.add_child(player)
	var library := AnimationLibrary.new()
	var run_animation := source.get_animation("Root|Run").duplicate() as Animation
	run_animation.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("run", run_animation)
	player.add_animation_library("", library)
	player.play("run")
	player.advance(0.0)
	run_instance.free()


func _apply_skin(node: Node, texture: Texture2D) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(surface)
			if material is StandardMaterial3D:
				var copy := material.duplicate() as StandardMaterial3D
				copy.albedo_color = Color.WHITE
				copy.albedo_texture = texture
				node.set_surface_override_material(surface, copy)
	for child in node.get_children():
		_apply_skin(child, texture)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
