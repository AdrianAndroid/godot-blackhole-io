class_name InputController
extends Control

var input_vector := Vector2.ZERO
var joystick_origin := Vector2.ZERO
var joystick_position := Vector2.ZERO
var joystick_visible: bool = false
var active_touch_id: int = -1
var mouse_active: bool = false
var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()
var max_distance: float = 64.0
var deadzone: float = 5.0
var idle_center := Vector2(76, 850)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	handle_event(event)


func handle_event(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_touch_id == -1 and not mouse_active:
				mouse_active = true
				_begin(event.position)
		elif mouse_active:
			clear()
	elif event is InputEventMouseMotion and mouse_active:
		_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			if active_touch_id == -1 and not mouse_active:
				active_touch_id = event.index
				_begin(event.position)
		elif event.index == active_touch_id:
			clear()
	elif event is InputEventScreenDrag and event.index == active_touch_id:
		_drag(event.position)


func _begin(position_value: Vector2) -> void:
	joystick_origin = position_value
	joystick_position = position_value
	joystick_visible = true
	_update_vector(position_value)


func _drag(position_value: Vector2) -> void:
	joystick_position = position_value
	_update_vector(position_value)


func _update_vector(position_value: Vector2) -> void:
	var offset := position_value - joystick_origin
	if offset.length() < deadzone:
		input_vector = Vector2.ZERO
	else:
		input_vector = offset.limit_length(max_distance) / max_distance
	queue_redraw()


func clear() -> void:
	input_vector = Vector2.ZERO
	joystick_visible = false
	joystick_origin = Vector2.ZERO
	joystick_position = Vector2.ZERO
	active_touch_id = -1
	mouse_active = false
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	if not joystick_visible:
		draw_circle(idle_center, 47.0, Color(0.12, 0.16, 0.34, 0.18))
		draw_arc(idle_center, 47.0, 0, TAU, 64, Color(0.92, 0.95, 1.0, 0.34), 2.0, true)
		draw_circle(idle_center, 21.0, Color(0.96, 0.98, 1.0, 0.36))
		draw_arc(idle_center, 21.0, 0, TAU, 48, Color(1, 1, 1, 0.50), 2.0, true)
		return
	draw_circle(joystick_origin, 50.0, Color(0.10, 0.12, 0.30, 0.32))
	draw_arc(joystick_origin, 50.0, 0, TAU, 64, Color(0.90, 0.94, 1.0, 0.78), 3.0, true)
	draw_arc(joystick_origin, 43.0, 0, TAU, 64, Color(0.61, 0.70, 1.0, 0.32), 2.0, true)
	var knob := joystick_origin + (joystick_position - joystick_origin).limit_length(40.0)
	draw_circle(knob, 22.0, Color(0.95, 0.98, 1, 0.92))
	draw_arc(knob, 22.0, 0, TAU, 48, Color.WHITE, 2.0, true)
	draw_circle(knob - Vector2(5, 6), 6.0, Color(1, 1, 1, 0.46))
