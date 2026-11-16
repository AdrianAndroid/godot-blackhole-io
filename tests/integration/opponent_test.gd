extends TestCase


func run() -> void:
	var session := _session(7001)
	expect(session.opponents.size() == 4, "新局四个假对手")
	var colors := {}
	var radii: Array[float] = []
	for index in 4:
		var opponent := session.opponents[index]
		colors[opponent.actor.faction_color.to_html()] = true
		radii.append(opponent.actor.effective_radius)
		expect(opponent.actor.effective_radius == session.layout.opponent_radii[index], "两小一接近一大配置")
	expect(colors.size() == 4, "四个不同阵营色")
	for index in 1200:
		session.step(1.0 / 60.0)
	for index in 4:
		expect(session.opponents[index].actor.effective_radius == radii[index], "整个对局对手不成长")

	var second := _session(7001)
	for index in 1200:
		second.step(1.0 / 60.0)
	var routes_equal := true
	for index in 4:
		routes_equal = routes_equal and session.opponents[index].position.is_equal_approx(second.opponents[index].position)
		expect(session.opponents[index].position.y == 0.0, "路线保持 XZ 平面")
		expect(absf(session.opponents[index].position.x) <= session.layout.map_size.x * 0.5 and absf(session.opponents[index].position.z) <= session.layout.map_size.y * 0.5, "路线不越界")
	expect(routes_equal, "固定步进路线位置可复现")
	expect(session.opponents[0].waypoint != 1, "路线节点切换")
	# Opponents never enter the player-opponent contact loop as each other's attacker.
	expect(session.swallow_manager.transactions.keys().all(func(id: int) -> bool: return id < 2000 or id >= 2004), "对手之间不互吞")
	session.free()
	second.free()

	var manager := SwallowManager.new()
	var hole := HoleActor.new()
	var target := Swallowable.new()
	target.kind = "opponent"
	target.setup({"id": "opponent", "footprint_radius": 1.0}, 3000, Node3D.new())
	hole.effective_radius = 1.099
	expect(not manager.try_claim(target, hole), "优势阈值下方不能吞")
	hole.effective_radius = 1.10
	expect(manager.try_claim(target, hole), "刚好 1.10 倍可吞")
	expect(not manager.try_claim(target, hole), "重复接触不重复吞噬")
	manager.free()
	hole.free()
	target.free()

	var knockout := _session(7002)
	knockout.player.effective_radius = 1.0
	knockout.opponents[0].position = knockout.player.position
	knockout.opponents[1].position = knockout.player.position
	knockout.step(0.01)
	knockout.step(1.0)
	expect(knockout.objective.knockdowns == 2, "窗口内连续击倒计数")
	expect(knockout.objective.multi_knockdown == 2, "多重击倒提示层级")
	expect(knockout.objective.current_score == 120, "击倒目标分奖励")
	var awarded := knockout.objective.current_score
	knockout.step(1.0)
	expect(knockout.objective.knockdowns == 2 and knockout.objective.current_score == awarded, "重复击倒不重复奖励")
	knockout.free()

	var outside := _session(7003)
	outside.player.effective_radius = 1.0
	outside.opponents[0].position = outside.player.position
	outside.step(0.01)
	outside.step(1.0)
	outside.objective.match_time += 5.0
	outside.opponents[1].position = outside.player.position
	outside.step(0.01)
	outside.step(1.0)
	expect(outside.objective.knockdowns == 2 and outside.objective.multi_knockdown == 1, "窗口外重新计算连击")
	outside.free()

	var death := _session(7004)
	death.opponents[3].position = death.player.position
	death.step(0.01)
	expect(death.player_death_target != null and death.state == GameSession.State.PLAYING, "玩家被吞先经历下沉")
	death.step(1.0)
	expect(death.state == GameSession.State.RESULT and death.result.get("reason") == "swallowed", "玩家被吞完成即失败")
	var frozen := str(death.snapshot())
	death.step(10.0)
	expect(str(death.snapshot()) == frozen, "死亡只产生一次结果且奖励冻结")
	death.free()


func _session(seed_value: int) -> GameSession:
	var session := GameSession.new()
	session.seed_value = seed_value
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	return session
