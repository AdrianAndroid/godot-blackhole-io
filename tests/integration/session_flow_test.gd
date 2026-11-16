extends TestCase


func run() -> void:
	var timer := _session(9000)
	timer.remaining_time = 0.2
	timer.step(0.1)
	expect(timer.state == GameSession.State.PLAYING and is_equal_approx(timer.remaining_time, 0.1), "倒计时正常递减")
	timer.step(0.1)
	expect(timer.state == GameSession.State.RESULT and timer.result.get("reason") == "timeout", "恰好归零自然超时失败")
	var timeout_score: int = timer.objective.current_score
	timer._completed_events.append({"object_id": 1, "kind": "normal", "score": 50, "coins": 5, "xp": 10})
	timer._process_completed_events()
	expect(timer.objective.current_score == timeout_score and timer.objective.coins == 0, "结果后事件不再发奖")
	timer.free()

	var priority := _session(9001)
	priority.remaining_time = 0.0
	priority._completed_events.append({"object_id": 900000, "kind": "player"})
	priority._completed_events.append({"object_id": 1000000, "kind": "tower"})
	priority._process_completed_events()
	expect(priority.result.get("reason") == "swallowed", "同帧死亡优先于高塔和超时")
	priority._process_completed_events()
	expect(priority.result.size() > 0 and priority.state == GameSession.State.RESULT, "结局唯一")
	priority.free()

	var tower_priority := _session(9002)
	tower_priority.remaining_time = 0.0
	tower_priority._completed_events.append({"object_id": 1000000, "kind": "tower"})
	tower_priority._process_completed_events()
	expect(tower_priority.result.get("reason") == "tower", "同帧高塔优先于超时")
	tower_priority.free()

	var paused := _session(9003)
	paused.driver_enabled = true
	paused.drive_input = Vector2.RIGHT
	paused.step(0.1)
	expect(paused.player.position.x > 0.0, "恢复状态正常移动")
	var target: Swallowable
	for object in paused.spawn_manager.objects.values():
		if object.footprint_radius < paused.player.effective_radius:
			target = object
			break
	paused.player.position = target.position
	paused.drive_input = Vector2.ZERO
	paused.step(0.01)
	expect(target.state == Swallowable.State.SINKING, "暂停前存在下沉事务")
	paused.pause()
	var frozen := str([paused.remaining_time, paused.player.position, target.progress])
	paused.drive_input = Vector2.RIGHT
	paused.step(10.0)
	expect(str([paused.remaining_time, paused.player.position, target.progress]) == frozen, "暂停冻结计时移动和吞噬")
	expect(paused.input_controller.input_vector == Vector2.ZERO and not paused.input_controller.enabled, "暂停清空输入")
	paused.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(paused.state == GameSession.State.PAUSED, "失焦不额外改变手动暂停")
	paused.resume()
	paused.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	expect(paused.state == GameSession.State.PLAYING, "失焦不自动暂停或恢复")
	paused.step(1.0)
	expect(target.state == Swallowable.State.SETTLED, "恢复后原吞噬继续完成")
	paused.free()

	var hud_session := _session(9004)
	hud_session._update_hud()
	expect(hud_session.hud.score_label.text == "目标 0/%d" % hud_session.objective.target_score, "HUD 目标与逻辑快照一致")
	expect(hud_session.hud.coins_label.text == "金币 0" and hud_session.hud.level_label.text == "大小 1", "HUD 金币体型一致")
	var all_text := _all_text(hud_session.hud.root_control)
	expect(not all_text.contains("商店") and not all_text.contains("广告"), "没有商店或广告占位入口")
	hud_session.free()

	var feedback := _session(9005)
	feedback.driver_enabled = true
	var target_object: Swallowable
	for object in feedback.spawn_manager.objects.values():
		if object.footprint_radius < feedback.player.effective_radius:
			target_object = object
			break
	feedback.player.position = target_object.position
	feedback.step(0.01)
	expect(feedback.attraction_bursts.size() == 1 and feedback.player.visual.feedback_pulse > 0.0, "真实认领触发吸附轨迹和洞口脉冲")
	expect(feedback.hud.floating_entries.is_empty() and feedback.objective.current_score == 0, "认领阶段不提前弹奖励")
	for tick in 60:
		feedback.step(0.01)
		if target_object.state == Swallowable.State.SETTLED:
			break
	expect(target_object.state == Swallowable.State.SETTLED and not feedback.hud.floating_entries.is_empty(), "完全结算后触发奖励飘字")
	expect(feedback.camera_rig.shake_strength > 0.0, "真实结算触发轻微镜头震动")
	var snapshot_before_projection := str(feedback.snapshot())
	feedback.camera_rig.add_shake(0.2)
	feedback.camera_rig.step(0.02, feedback.player.position, feedback.player.effective_radius)
	expect(str(feedback.snapshot()) == snapshot_before_projection, "镜头震动不进入玩法逻辑快照")
	for tick in 110:
		feedback.hud.step(0.01)
	expect(feedback.hud.floating_entries.is_empty(), "飘字固定步进结束后清理节点")
	feedback.free()

	var unready := GameSession.new()
	expect(unready.state == GameSession.State.READY, "Session 创建为 READY")
	unready.free()
	await _retry_checks()


func _retry_checks() -> void:
	var baseline_children := tree.root.get_child_count()
	var app := GameApp.new()
	tree.root.add_child(app)
	expect(app.home_screen != null and app.session == null, "HOME 无活动 Session")
	app.start_session(99)
	var first := app.session
	first.automatic = false
	first.audio.muted = true
	var signature := first.layout.signature
	var count := first.spawn_manager.objects.size()
	first.input_controller.input_vector = Vector2.ONE
	first.objective.coins = 8
	app.retry_session()
	var retry := app.session
	retry.automatic = false
	retry.audio.muted = true
	await tree.process_frame
	expect(retry != first and retry.layout.signature == signature, "销毁 Session 同图重试")
	expect(retry.remaining_time == 600.0 and retry.objective.coins == 0 and retry.growth.level == 1, "重试计时和本局数据归零")
	expect(retry.input_controller.input_vector == Vector2.ZERO and retry.swallow_manager.transactions.is_empty(), "重试无残留输入和动画")
	expect(retry.spawn_manager.objects.size() == count and retry.audio.event_counts.is_empty(), "重试对象和音频事件恢复基线")
	app.start_session()
	var new_session := app.session
	new_session.automatic = false
	new_session.audio.muted = true
	await tree.process_frame
	expect(new_session.layout.signature != signature and new_session.seed_value != 99, "首页新局换图")
	app.show_home()
	await tree.process_frame
	expect(app.session == null and app.home_screen != null, "返回首页销毁 Session")
	expect(tree.root.get_child_count() == baseline_children + 1, "旧 Session 节点全部清理")
	app.queue_free()
	await tree.process_frame
	expect(tree.root.get_child_count() == baseline_children, "应用销毁后节点回基线")


func _all_text(node: Node) -> String:
	var text := ""
	if node is Label or node is Button:
		text += node.text + "\n"
	for child in node.get_children():
		text += _all_text(child)
	return text


func _session(seed_value: int) -> GameSession:
	var session := GameSession.new()
	session.seed_value = seed_value
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	return session
