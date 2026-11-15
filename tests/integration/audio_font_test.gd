extends TestCase


func run() -> void:
	for cue in AudioManager.CUES:
		var stream: AudioStream = load(AudioManager.CUES[cue])
		expect(stream != null and stream.get_length() > 0.0, "音效资源有效: " + cue)
	var font: Font = load("res://assets/game/fonts/NotoSansSC-Variable.ttf")
	var chinese := "黑洞城市第关适中开始对局拖动摇杆移动吞噬完成目标体型金币击倒连击最大金色高塔已出现东南北胜利本失败重试同一张返回新暂停继续时间"
	var missing: Array[int] = []
	for index in chinese.length():
		if not font.has_char(chinese.unicode_at(index)):
			missing.append(chinese.unicode_at(index))
	expect(missing.is_empty(), "首页 HUD 满级连击和结算中文字形完整")

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
	session.audio.stop_all()
	await tree.process_frame
	session.free()
