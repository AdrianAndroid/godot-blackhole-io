extends TestCase


func run() -> void:
	var session := _session(8100)
	_unlock_with_buildings(session)
	expect(session.objective.completion() == 1.0, "普通建筑恰好或超过 100% 封顶")
	expect(session.objective.knockdowns == 0 and session.living_opponents() == 4, "零击倒且四对手存活仍解锁")
	expect(session.tower != null, "唯一金色高塔出现")
	var tower_id := session.tower.get_instance_id()
	var score := session.objective.current_score
	session.objective.settle({"object_id": 999001, "kind": "normal", "score": 100, "coins": 0})
	expect(session.tower.get_instance_id() == tower_id, "重复越过 100% 不重建高塔")
	expect(session.objective.current_score == score + 100 and session.objective.completion() == 1.0, "超过目标仍累计分数且完成度封顶")
	expect(session.hud.direction_label.text.contains("高塔"), "高塔方向指引")
	session.free()

	var victory := _session(8101)
	_unlock_with_buildings(victory)
	var unlocked_score := victory.objective.current_score
	expect(victory.growth.level < 19, "未满 19 级高塔夹具")
	victory.player.position = victory.tower.position
	victory.step(0.01)
	expect(victory.tower.state == Swallowable.State.SINKING and victory.state == GameSession.State.PLAYING, "高塔动画中尚未胜利")
	victory.step(1.3)
	expect(victory.result.get("victory") == true and victory.result.get("reason") == "tower", "高塔完全下沉后胜利")
	expect(victory.hud.result_title.text == "胜利！" and victory.hud.result_panel.visible, "胜利结算文字与面板")
	expect(victory.objective.current_score == unlocked_score and victory.growth.experience == 0, "高塔不追加普通奖励")
	victory.free()

	var timeout := _session(8102)
	_unlock_with_buildings(timeout)
	timeout.player.position = timeout.tower.position
	timeout.remaining_time = 0.05
	timeout.step(0.01)
	timeout.step(0.1)
	expect(timeout.result.get("victory") == false and timeout.result.get("reason") == "timeout", "高塔下沉期间超时失败")
	expect(timeout.hud.result_title.text == "本局失败" and timeout.hud.result_panel.visible, "失败结算文字与面板")
	expect(timeout.tower.state != Swallowable.State.SETTLED, "超时取消未完成高塔")
	timeout.free()

	var rewards := ObjectiveManager.new()
	rewards.configure(100)
	rewards.settle({"object_id": 1, "kind": "normal", "score": 20, "coins": 2})
	rewards.settle({"object_id": 2, "kind": "normal", "score": 20, "coins": 0})
	expect(rewards.coins == 2 and rewards.current_score == 40, "含金币与无金币物体分别结算")
	rewards.reset()
	expect(rewards.coins == 0 and rewards.current_score == 0 and not rewards.tower_unlocked, "重试或新局本局数据归零")


func _unlock_with_buildings(session: GameSession) -> void:
	for placement in session.layout.objects:
		var entry: Dictionary = session.generator._catalog_entry(placement.model_id)
		session.objective.settle({"object_id": placement.id, "kind": "normal", "score": entry.score, "coins": entry.coins, "xp": 0})
		if session.objective.tower_unlocked:
			break
	session._update_hud()


func _session(seed_value: int) -> GameSession:
	var session := GameSession.new()
	session.seed_value = seed_value
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	return session
