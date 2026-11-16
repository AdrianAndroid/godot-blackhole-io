extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			path = argument.trim_prefix("--report=")
	if path.is_empty():
		push_error("用法: -- --report=artifacts/failures/<name>.json")
		quit(2)
		return
	var report := FailureReporter.load_report(path)
	if report.is_empty():
		push_error("故障报告不存在或格式错误: " + path)
		quit(2)
		return
	var result := FailureReporter.replay(report, self)
	print(JSON.stringify(result))
	quit(0 if result.passed else 1)
