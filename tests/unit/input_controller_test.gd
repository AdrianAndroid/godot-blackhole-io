extends TestCase


func run() -> void:
	var controller := InputController.new()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 700)
	controller.handle_event(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(132, 668)
	controller.handle_event(drag)
	var mouse_vector := controller.input_vector
	expect_near(mouse_vector.x, 0.5, 0.0001, "鼠标标准化 X")
	expect_near(mouse_vector.y, -0.5, 0.0001, "鼠标标准化 Y")
	expect(controller.joystick_visible, "鼠标拖动显示摇杆")
	press = press.duplicate()
	press.pressed = false
	controller.handle_event(press)
	expect(controller.input_vector == Vector2.ZERO and not controller.joystick_visible, "释放归零并隐藏")

	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = Vector2(100, 700)
	controller.handle_event(touch)
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.index = 7
	touch_drag.position = Vector2(132, 668)
	controller.handle_event(touch_drag)
	expect(controller.input_vector.is_equal_approx(mouse_vector), "触摸与鼠标向量一致")
	var second := InputEventScreenTouch.new()
	second.index = 8
	second.pressed = true
	second.position = Vector2(400, 100)
	controller.handle_event(second)
	var second_drag := InputEventScreenDrag.new()
	second_drag.index = 8
	second_drag.position = Vector2(10, 10)
	controller.handle_event(second_drag)
	expect(controller.active_touch_id == 7, "第二指不能夺取所有权")
	expect(controller.input_vector.is_equal_approx(mouse_vector), "第二指不改变方向")
	touch = touch.duplicate()
	touch.pressed = false
	touch.canceled = true
	controller.handle_event(touch)
	expect(controller.active_touch_id == -1 and controller.input_vector == Vector2.ZERO, "取消触摸后停止")
	controller.free()
