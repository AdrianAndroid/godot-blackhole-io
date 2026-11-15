extends SceneTree

var results: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_unix_time_from_system()
	var filter := ""
	var skip := ""
	var group := "all"
	var report_name := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--filter="):
			filter = argument.trim_prefix("--filter=")
		elif argument.begins_with("--skip="):
			skip = argument.trim_prefix("--skip=")
		elif argument.begins_with("--group="):
			group = argument.trim_prefix("--group=")
		elif argument.begins_with("--report="):
			report_name = argument.trim_prefix("--report=").get_file()
	if report_name.is_empty():
		report_name = "unit.json" if group == "unit" and filter.is_empty() else "logic.json"
	if not report_name.ends_with(".json"):
		report_name += ".json"
	var directories: Array[String] = []
	if group in ["all", "unit"]:
		directories.append("res://tests/unit")
	if group in ["all", "integration"]:
		directories.append("res://tests/integration")
	for directory_path in directories:
		var files := DirAccess.get_files_at(directory_path)
		files.sort()
		for file in files:
			if not file.ends_with("_test.gd") or (filter != "" and not file.contains(filter)) or (skip != "" and file.contains(skip)):
				continue
			var path := directory_path + "/" + file
			var test_started := Time.get_ticks_usec()
			var script: Script = load(path)
			if script == null or not script.can_instantiate():
				results.append({"name": path, "checks": 0, "duration_ms": 0.0, "failures": ["测试脚本无法加载或编译"]})
				continue
			var test: TestCase = script.new()
			if test == null:
				results.append({"name": path, "checks": 0, "duration_ms": 0.0, "failures": ["测试实例创建失败"]})
				continue
			test.tree = self
			await test.run()
			var test_failures := test.failures.duplicate()
			if test.checks == 0:
				test_failures.append("测试未执行任何断言，不能视为通过")
			results.append({"name": path.trim_prefix("res://tests/"), "checks": test.checks, "duration_ms": snappedf(float(Time.get_ticks_usec() - test_started) / 1000.0, 0.001), "failures": test_failures})
	if "--self-test-fail" in OS.get_cmdline_user_args():
		results.append({"name": "intentional_failure", "checks": 1, "duration_ms": 0.0, "failures": ["请求的故意失败"]})
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var checks := 0
	for result in results:
		checks += int(result.checks)
	var passed := results.all(func(result: Dictionary) -> bool: return result.failures.is_empty()) and not results.is_empty() and checks > 0
	var report := {"suite": group, "filter": filter, "skip": skip, "passed": passed, "engine": Engine.get_version_info().string, "platform": OS.get_name(), "started_unix": started, "duration_seconds": snappedf(Time.get_unix_time_from_system() - started, 0.001), "checks": checks, "report": "artifacts/" + report_name, "results": results}
	var output := FileAccess.open("res://artifacts/" + report_name, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed else 1)
