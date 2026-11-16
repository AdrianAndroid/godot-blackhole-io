extends TestCase


func run() -> void:
	var hud := HudController.new()
	hud.build()
	hud.update_values({"score": 81, "target": 1215, "remaining": 567.0, "level": 3, "experience": 17, "coins": 4, "completion": 0.0667, "knockdowns": 0})
	expect(hud.time_label.text == "09:27", "顶部圆环显示分秒格式倒计时")
	expect(hud.objective_label.text == "6.7%" and is_equal_approx(hud.graphics.completion, 0.0667), "胶囊完成度与目标管理器一致")
	expect(is_equal_approx(hud.graphics.experience_progress, 0.5), "黄色经验条使用当前等级区间经验")
	expect(hud.score_label.text == "目标 81/1215" and hud.level_label.text == "大小 3" and hud.coins_label.text == "金币 4", "目标体型和金币独立显示")
	hud.update_values({"score": 1300, "target": 1215, "remaining": 0.0, "level": 19, "experience": 10000, "coins": 8, "completion": 1.0, "knockdowns": 2})
	expect(hud.graphics.completion == 1.0 and hud.graphics.experience_progress == 1.0 and hud.level_label.text == "最大体型", "完成度和满级经验条封顶")
	var safe := true
	for rect in hud.safe_rects:
		safe = safe and rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 432 and rect.end.y <= 960
	expect(safe, "全部固定 HUD 区域位于竖屏安全范围")
	hud.show_result({"victory": true, "completion": 1.0, "score": 1300, "coins": 8, "level": 19, "knockdowns": 2})
	expect(hud.result_panel.visible and hud.result_shade.visible and hud.result_title.text == "抵达终点！", "结算面板和遮罩同步显示")
	hud.free()
