extends TestCase


func run() -> void:
	expect(SwallowManager.qualifies(1.0, 0.99), "严格更小可吞")
	expect(not SwallowManager.qualifies(1.0, 1.0), "相等不可吞")
	expect(not SwallowManager.qualifies(1.0, 1.01), "更大不可吞")
	expect(SwallowManager.qualifies(1.0, 0.9999999), "浮点边界内可吞")
	expect(not SwallowManager.qualifies(1.0, 1.0000001), "浮点边界外不可吞")

	var manager := SwallowManager.new()
	var hole := HoleActor.new()
	hole.effective_radius = 1.0
	var object := _object(10, 0.8)
	var events: Array[Dictionary] = []
	manager.completed.connect(func(event: Dictionary) -> void: events.append(event))
	expect(manager.try_claim(object, hole), "首次声明成功")
	expect(object.state == Swallowable.State.SINKING, "进入下沉")
	expect(not manager.try_claim(object, hole), "重复 Area 回调不能重复声明")
	var other_hole := HoleActor.new()
	other_hole.effective_radius = 2.0
	expect(not manager.try_claim(object, other_hole), "两个黑洞竞争只有唯一归属")
	manager.step(0.1)
	expect(events.is_empty(), "动画前不发奖")
	manager.step(0.25)
	expect(events.is_empty(), "动画中不发奖")
	manager.step(0.3)
	expect(events.size() == 1 and object.state == Swallowable.State.SETTLED, "完全消失后一次发奖")
	manager.step(1.0)
	expect(events.size() == 1, "完成后继续步进不重复发奖")
	object.free()
	other_hole.free()
	manager.free()

	var cancel_manager := SwallowManager.new()
	var cancel_object := _object(11, 0.8)
	var cancel_events: Array[Dictionary] = []
	cancel_manager.completed.connect(func(event: Dictionary) -> void: cancel_events.append(event))
	cancel_manager.try_claim(cancel_object, hole)
	cancel_manager.step(0.2)
	cancel_manager.cancel_all()
	expect(cancel_events.is_empty(), "对局中途取消不补发奖励")
	expect(cancel_object.state == Swallowable.State.IDLE and cancel_object.visible, "取消恢复物体")
	cancel_object.free()
	cancel_manager.free()

	var exit_manager := SwallowManager.new()
	var exit_object := _object(12, 0.8)
	var exit_events: Array[Dictionary] = []
	exit_manager.completed.connect(func(event: Dictionary) -> void: exit_events.append(event))
	exit_manager.try_claim(exit_object, hole)
	exit_object.free()
	exit_manager.step(1.0)
	expect(exit_events.is_empty() and exit_manager.transactions.is_empty(), "节点退出不结算且事务清理")
	exit_manager.free()

	var tower_manager := SwallowManager.new()
	var tower := _object(20, 100.0)
	tower.kind = "tower"
	expect(tower_manager.try_claim(tower, hole), "高塔无视普通半径门槛")
	tower_manager.step(1.0)
	tower.free()
	tower_manager.free()
	hole.free()

	var growth := GrowthManager.new()
	expect(growth.level == 1 and growth.add_experience(4).is_empty(), "阈值前不升级")
	expect(growth.add_experience(1) == [2], "恰好阈值升级")
	expect(growth.add_experience(85) == [3, 4, 5, 6, 7], "单次跨多级")
	expect(growth.experience == 90, "超额经验不丢失")
	growth.add_experience(100000)
	expect(growth.level == 19 and growth.radius == GrowthManager.RADII[18], "等级与半径不超界")
	var old_radius := growth.radius
	growth.add_experience(50)
	expect(growth.radius == old_radius and growth.experience == 100140, "满级经验累计但半径固定")
	for index in range(1, GrowthManager.RADII.size()):
		expect(GrowthManager.RADII[index] > GrowthManager.RADII[index - 1], "半径表单调")

	var objective := ObjectiveManager.new()
	objective.configure(101)
	expect(objective.target_score == 76, "目标总分 ceil 75%")
	var reward := {"object_id": 100, "kind": "normal", "xp": 7, "score": 40, "coins": 3}
	var independent_growth := GrowthManager.new()
	if objective.settle(reward):
		independent_growth.add_experience(reward.xp)
	expect(objective.current_score == 40 and objective.coins == 3, "目标分和金币独立")
	expect(independent_growth.experience == 7 and independent_growth.level == 2, "经验独立结算")
	objective.settle(reward)
	expect(objective.current_score == 40 and objective.coins == 3, "重复完成事件数值不变")
	objective.settle({"object_id": 101, "kind": "normal", "score": 100, "coins": 0})
	expect(objective.completion() == 1.0 and objective.tower_unlocked, "完成度封顶并解锁")


func _object(id: int, radius: float) -> Swallowable:
	var object := Swallowable.new()
	object.setup({"id": "test", "footprint_radius": radius, "xp": 7, "score": 9, "coins": 2}, id, Node3D.new())
	return object
