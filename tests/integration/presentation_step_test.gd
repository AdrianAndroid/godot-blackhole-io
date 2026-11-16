extends TestCase


func run() -> void:
	var session := GameSession.new()
	session.seed_value = 5150
	tree.root.add_child(session)
	session.automatic = false
	session.audio.muted = true
	var initial_time := session.camera_rig.visual_time
	var opponent_time: float = session.opponents[0].actor.visual.animation_time
	session._physics_process(0.1)
	expect(is_equal_approx(session.remaining_time, 600.0), "手动模式关闭自动物理推进")
	session.automatic = true
	session._physics_process(0.1)
	expect(session.remaining_time < 600.0 and session.camera_rig.visual_time == initial_time, "物理推进不提前更新镜头")
	expect(session.opponents[0].actor.visual.animation_time == opponent_time, "物理推进不提前更新对手动画: %.4f -> %.4f" % [opponent_time, session.opponents[0].actor.visual.animation_time])
	var remaining := session.remaining_time
	session._process(0.02)
	expect_near(session.camera_rig.visual_time, initial_time + 0.02, 0.00001, "渲染帧只推进一次镜头")
	expect_near(session.opponents[0].actor.visual.animation_time, maxf(0.0, opponent_time) + 0.02, 0.00001, "对手动画也只随渲染帧推进")
	expect(session.remaining_time == remaining, "渲染推进不改变玩法计时")
	session.pause()
	var paused_time := session.camera_rig.visual_time
	session._process(0.1)
	expect(session.camera_rig.visual_time == paused_time, "暂停时渲染帧冻结镜头")
	session.resume()
	remaining = session.remaining_time
	session.step(0.1)
	expect_near(session.camera_rig.visual_time, paused_time + 0.1, 0.00001, "手动整局入口保持逻辑和表现同步")
	expect_near(session.remaining_time, remaining - 0.1, 0.00001, "手动入口不重复推进逻辑")
	var before := str(session.snapshot())
	session.toggle_projection()
	expect(str(session.snapshot()) == before, "运动中的投影切换不改变玩法状态")
	session.automatic = false
	session.free()
