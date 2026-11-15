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
	expect(hole.disk.position.y > 0.0 and hole.disk.position.y < 0.1, "黑洞贴地")
	hole.free()
