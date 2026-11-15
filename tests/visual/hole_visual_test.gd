extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(432, 960)
	root.content_scale_size = Vector2i(432, 960)
	var scene := Node3D.new()
	root.add_child(scene)
	CityVisuals.add_lighting(scene)
	CityVisuals.add_ground(scene, Vector2(14, 18))
	CityVisuals.add_water(scene, Vector2(3.5, 0), Vector2(7, 18))
	var land_hole := HoleVisual.new()
	land_hole.effective_radius = 0.8
	land_hole.faction_color = Color("438dff")
	land_hole.position = Vector3(-3, 0, 0)
	scene.add_child(land_hole)
	var water_hole := HoleVisual.new()
	water_hole.effective_radius = 2.4
	water_hole.faction_color = Color("ff536d")
	water_hole.position = Vector3(3, 0, 0)
	scene.add_child(water_hole)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 13, 12)
	scene.add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/visual")
	var error := root.get_texture().get_image().save_png("res://artifacts/visual/holes_land_water.png")
	var passed := error == OK and DisplayServer.get_name() != "headless" and is_equal_approx((land_hole.disk.mesh as PlaneMesh).size.x, 1.6) and is_equal_approx((water_hole.disk.mesh as PlaneMesh).size.x, 4.8)
	var report := {"passed": passed, "land_radius": land_hole.effective_radius, "water_radius": water_hole.effective_radius, "renderer": DisplayServer.get_name(), "screenshot": "artifacts/visual/holes_land_water.png"}
	var output := FileAccess.open("res://artifacts/visual/holes.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed else 1)
