extends TestCase


func run() -> void:
	for cue in AudioManager.CUES:
		var stream: AudioStream = load(AudioManager.CUES[cue])
		expect(stream != null and stream.get_length() > 0.0, "音效资源有效: " + cue)
	var font: Font = load("res://assets/game/fonts/NotoSansSC-Game.ttf")
	var chinese := "黑洞城市第关适中开始对局拖动摇杆移动吞噬完成目标体型金币击倒连击最大金色高塔已出现东南北胜利本失败重试同一张返回新暂停继续时间终点解锁度下沉抵达"
	var missing: Array[int] = []
	for index in chinese.length():
		if not font.has_char(chinese.unicode_at(index)):
			missing.append(chinese.unicode_at(index))
	expect(missing.is_empty(), "首页 HUD 满级连击和结算中文字形完整")
	var missing_ascii: Array[int] = []
	for codepoint in range(32, 127):
		if not font.has_char(codepoint):
			missing_ascii.append(codepoint)
	expect(missing_ascii.is_empty(), "动态数字时间百分比和 ASCII 标点字形完整")
	var wght_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	expect(font.get_supported_variation_list().has(wght_tag), "运行字体保留可变 wght 字重轴")

	var session := GameSession.new()
	session.seed_value = 6060
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	var target: Swallowable
	for object in session.spawn_manager.objects.values():
		if object.footprint_radius < session.player.effective_radius:
			target = object
			break
	session.player.position = target.position
	session.step(0.01)
	session.audio.muted = false
	session.audio.volume_db = -24.0
	session.step(1.0)
	expect(session.audio.event_counts.get("devour", 0) == 1, "一次吞噬事件只播放一次")
	var city_loop: AudioStreamPlayer = session.audio.active_players.get("city_ambience")
	var motion_loop: AudioStreamPlayer = session.audio.active_players.get("hole_move")
	var water_loop: AudioStreamPlayer = session.audio.active_players.get("water_ambience")
	expect(city_loop != null and city_loop.playing and motion_loop != null and water_loop != null, "城市、移动和临水三层循环同时运行")
	expect(session.audio.event_counts.get("city_ambience", 0) == 0, "环境循环不污染玩法音效事件计数")
	session.audio.update_environment(1.0, 5.0, 1.0)
	expect(motion_loop.pitch_scale > 1.1 and water_loop.volume_db > city_loop.volume_db, "成长和临水距离实际改变声音层次")
	session.audio.pause_environment()
	expect(city_loop.stream_paused and motion_loop.stream_paused and water_loop.stream_paused, "暂停冻结所有环境循环")
	session.audio.resume_environment()
	expect(not city_loop.stream_paused and not motion_loop.stream_paused and not water_loop.stream_paused, "恢复后继续环境循环")
	var player: AudioStreamPlayer = session.audio.active_players.get("devour")
	expect(player != null and is_equal_approx(player.volume_db, -24.0), "音量设置生效")
	session.audio.stop_all()
	await tree.process_frame
	await tree.process_frame
	session.audio.muted = true
	var count: int = session.audio.event_counts.devour
	session.audio.play("devour")
	expect(session.audio.event_counts.devour == count + 1 and not player.playing, "静音记录事件但无音频输出")
	var before := session.snapshot()
	session.step(0.1)
	expect(session.remaining_time < before.remaining, "静音后玩法继续")
	var fence: Swallowable
	for object in session.spawn_manager.objects.values():
		if object.model_id == "perimeter_fence" and object.position.x < -54.0:
			fence = object
			break
	expect(fence != null, "地图外缘存在真实可吞围栏")
	if fence != null:
		session.audio.muted = false
		session.player.position = fence.position
		session.step(0.01)
		session.step(1.0)
		expect(session.audio.event_counts.get("devour_fence", 0) == 1 and fence.state == Swallowable.State.SETTLED, "一级围栏完成独立音效与一次性吞噬结算")
	session.audio.stop_all()
	await tree.process_frame
	session.free()
