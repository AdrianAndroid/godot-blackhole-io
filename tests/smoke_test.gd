extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := false
	var details: Array[String] = []
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		failed = true
		details.append("主场景无法加载")
	else:
		var app = packed.instantiate()
		root.add_child(app)
		await process_frame
		if not is_instance_valid(app.home_screen):
			failed = true
			details.append("首页未创建")
		if app.get_node_or_null("HomeScreen/StartButton") == null and app.home_screen != null:
			# The button is nested in layout containers; recursive lookup is checked below.
			var button: Node = app.home_screen.find_child("StartButton", true, false)
			if button == null:
				failed = true
				details.append("开始按钮未创建")
		app.start_session(1)
		await process_frame
		if not is_instance_valid(app.session):
			failed = true
			details.append("Session 未创建")
		app.queue_free()
	if "--self-test-fail" in OS.get_cmdline_user_args():
		failed = true
		details.append("请求的故意失败")
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var report := {"suite": "smoke", "passed": not failed, "details": details}
	var file := FileAccess.open("res://artifacts/smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	quit(1 if failed else 0)
