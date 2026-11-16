extends TestCase


func run() -> void:
	var hole := HoleVisual.new()
	hole.effective_radius = 0.8
	hole.faction_color = Color("ff5a68")
	hole.build()
	expect_near((hole.disk.mesh as PlaneMesh).size.x, 1.6, 0.0001, "小半径视觉与逻辑同步")
	hole.effective_radius = 2.4
	expect_near((hole.disk.mesh as PlaneMesh).size.x, 4.8, 0.0001, "成长半径视觉与逻辑同步")
	expect_near(hole.visual_diameter(), hole.effective_radius * 2.0, 0.0001, "单一有效半径来源")
	expect(hole.hole_material.get_shader_parameter("faction_color") == hole.faction_color, "阵营色同步")
	expect(hole.glow_material.get_shader_parameter("faction_color") == hole.faction_color and hole.rim_material.emission == hole.faction_color, "光晕和厚环共享阵营色")
	expect(hole.disk.position.y > 0.0 and hole.disk.position.y < 0.1, "黑洞贴地")
	expect(hole.glow.position.y < hole.disk.position.y and hole.rim.position.y > hole.disk.position.y, "光晕深井厚环层次清晰")
	expect_near((hole.glow.mesh as PlaneMesh).size.x, 4.8 * 1.55, 0.0001, "地面光晕超出洞口但不改变逻辑半径")
	expect_near((hole.rim.mesh as TorusMesh).outer_radius, 2.4 * 0.985, 0.0001, "立体厚环随有效半径成长")
	expect(hole.edge_particles.size() == HoleVisual.PARTICLE_COUNT, "洞口边缘具有真实三维光点")
	hole.animation_time = 2.0
	var frozen_particle := hole.edge_particles[0].position
	hole.animation_time = 2.0
	expect(hole.edge_particles[0].position == frozen_particle, "相同固定动画时间得到完全相同的粒子位置")
	hole.animation_time = 2.1
	expect(hole.edge_particles[0].position != frozen_particle, "边缘粒子由动画时间驱动")
	hole.trigger_pulse(1.0)
	expect(is_equal_approx(hole.feedback_pulse, 1.0), "认领和结算可触发洞口脉冲")
	hole.step(0.1)
	expect(hole.feedback_pulse < 1.0 and hole.animation_time > 2.1, "视觉脉冲和动画固定步进推进")
	hole.free()
