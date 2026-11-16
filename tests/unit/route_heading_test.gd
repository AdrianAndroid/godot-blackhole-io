extends TestCase


func run() -> void:
	var registry := ModelRegistry.new()
	for model_id in ["sedan", "taxi", "police", "delivery", "ambulance", "duck"]:
		var model := registry.instantiate(model_id)
		var entry := registry.get_entry(model_id)
		if model_id == "duck":
			expect(is_zero_approx(float(entry.rotation_y)), "鸭子保持本地 -Z 车头/朝向约定")
		else:
			expect(is_equal_approx(float(entry.rotation_y), 180.0), model_id + " 的 +Z 车头转换到路线 -Z 约定")
		var object := Swallowable.new()
		object.setup(entry, 100, model)
		object.configure_route(PackedVector3Array([
			Vector3(-2, 0, -2), Vector3(2, 0, -2),
			Vector3(2, 0, 2), Vector3(-2, 0, 2),
		]), 2.0)
		var directions := {}
		var previous := object.position
		var aligned := true
		for tick in 160:
			object.advance_route(0.05)
			var displacement := object.position - previous
			previous = object.position
			if displacement.length_squared() < 0.000001:
				continue
			var direction := displacement.normalized()
			var local_front := Vector3.FORWARD if model_id == "duck" else Vector3.BACK
			var visual_front := (object.basis * model.basis * local_front).normalized()
			# At a waypoint the new heading is applied on arrival; a tick crossing
			# a corner follows its chord. Neither case may move backwards.
			var at_corner := false
			for point in object.motion_route:
				at_corner = at_corner or object.position.distance_squared_to(point) < 0.000001
			var straight := maxf(absf(direction.x), absf(direction.z)) > 0.999
			var threshold := 0.999 if straight and not at_corner else -0.001
			var alignment := visual_front.dot(direction)
			aligned = aligned and alignment > threshold
			if absf(direction.x) > 0.9:
				directions["east" if direction.x > 0 else "west"] = true
			elif absf(direction.z) > 0.9:
				directions["south" if direction.z > 0 else "north"] = true
		expect(aligned, model_id + " 全路线车头与实际位移同向")
		expect(directions.size() == 4, model_id + " 四个路线方向均经过朝向检查")
		object.free()
