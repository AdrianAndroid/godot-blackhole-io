class_name HudController
extends CanvasLayer

signal retry_requested
signal home_requested

var root_control: Control
var graphics: HudGraphics
var score_label: Label
var time_label: Label
var level_label: Label
var coins_label: Label
var message_label: Label
var objective_label: Label
var direction_label: Label
var result_shade: ColorRect
var result_panel: PanelContainer
var result_title: Label
var result_stats: Label
var last_values: Dictionary = {}
var safe_rects: Array[Rect2] = []
var floating_entries: Array[Dictionary] = []
var combo_count: int = 0
var combo_window: float = 0.0
var feedback_serial: int = 0


func _ready() -> void:
	build()


func build() -> void:
	if root_control != null:
		return
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/game/fonts/NotoSansSC-Variable.ttf")
	font.variation_opentype = {"wght": 650.0}
	font.variation_embolden = 0.25
	theme.default_font = font
	theme.default_font_size = 18
	root_control.theme = theme
	graphics = HudGraphics.new()
	graphics.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(graphics)

	time_label = _label(root_control, "10:00")
	_place(time_label, Rect2(15, 34, 78, 38), 22, Color.WHITE, 4)
	objective_label = _label(root_control, "0.0%")
	_place(objective_label, Rect2(135, 31, 200, 43), 24, Color.WHITE, 5)
	score_label = _label(root_control, "目标 0/1")
	_place(score_label, Rect2(108, 85, 212, 25), 13, Color("e8ecff"), 2)
	coins_label = _label(root_control, "金币 0")
	_place(coins_label, Rect2(350, 64, 70, 25), 13, Color("fff1a0"), 2)
	level_label = _label(root_control, "大小 1")
	_place(level_label, Rect2(142, 867, 214, 38), 22, Color.WHITE, 4)
	message_label = _label(root_control, "")
	_place(message_label, Rect2(24, 120, 384, 40), 18, Color("ffe36a"), 4)
	direction_label = _label(root_control, "")
	_place(direction_label, Rect2(24, 163, 384, 38), 16, Color("d7e8ff"), 3)
	safe_rects = [
		Rect2(10, 8, 88, 92), Rect2(86, 20, 276, 92), Rect2(348, 22, 74, 70),
		Rect2(message_label.position, message_label.size), Rect2(direction_label.position, direction_label.size),
		Rect2(116, 830, 266, 78), Rect2(30, 280, 372, 392)
	]
	_build_result()


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _place(label: Label, rect: Rect2, font_size: int, color: Color, outline: int) -> void:
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("182047"))
	label.add_theme_constant_override("outline_size", outline)


func update_values(values: Dictionary) -> void:
	last_values = values.duplicate()
	score_label.text = "目标 %d/%d" % [values.score, values.target]
	time_label.text = "%02d:%02d" % [int(values.remaining) / 60, int(values.remaining) % 60]
	level_label.text = "最大体型" if values.level == 19 else "大小 %d" % values.level
	coins_label.text = "金币 %d" % values.coins
	objective_label.text = "%.1f%%" % [float(values.completion) * 100.0]
	graphics.remaining = float(values.remaining)
	graphics.completion = clampf(float(values.completion), 0.0, 1.0)
	var level := clampi(int(values.level), 1, GrowthManager.MAX_LEVEL)
	if level == GrowthManager.MAX_LEVEL:
		graphics.experience_progress = 1.0
	else:
		var lower := GrowthManager.THRESHOLDS[level - 1]
		var upper := GrowthManager.THRESHOLDS[level]
		graphics.experience_progress = clampf(float(int(values.get("experience", 0)) - lower) / float(upper - lower), 0.0, 1.0)
	graphics.queue_redraw()


func show_message(text: String) -> void:
	message_label.text = text


func set_tower_direction(text: String) -> void:
	direction_label.text = text


func step(delta: float) -> void:
	combo_window = maxf(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_count = 0
	for index in range(floating_entries.size() - 1, -1, -1):
		var entry := floating_entries[index]
		entry.age = float(entry.age) + delta
		var label := entry.label as Label
		label.position.y -= delta * 34.0
		var progress := float(entry.age) / float(entry.duration)
		label.modulate.a = 1.0 - smoothstep(0.62, 1.0, progress)
		if progress >= 1.0:
			label.queue_free()
			floating_entries.remove_at(index)


func show_devour(event: Dictionary, levels: Array, screen_position: Vector2) -> void:
	if root_control == null:
		return
	feedback_serial += 1
	var opponent := str(event.kind) == "opponent"
	if opponent:
		combo_count = 0
		combo_window = 0.0
	else:
		combo_count = combo_count + 1 if combo_window > 0.0 else 1
		combo_window = 1.35
	var origin := Vector2(clampf(screen_position.x - 90.0, 12.0, 240.0), clampf(screen_position.y - 52.0, 230.0, 780.0))
	origin.x += float(feedback_serial % 3 - 1) * 18.0
	origin.y -= float(feedback_serial % 4) * 24.0
	var text := "+%d" % int(event.score)
	var color := Color("ffffff")
	if opponent:
		text = "击倒！ +" + str(int(event.score))
		color = Color("ffcf4a")
	_spawn_float(text, origin, color, 30)
	if int(event.coins) > 0:
		_spawn_float("金币 +%d" % int(event.coins), origin + Vector2(28, 34), Color("ffe16a"), 19)
	if combo_count >= 3 and not opponent:
		_spawn_float("连吞 x%d" % combo_count, origin + Vector2(18, 65), Color("70f5ff"), 20)
	for level in levels:
		_spawn_float("体型提升 · Lv.%d" % int(level), origin + Vector2(-10, 68), Color("7dff9b"), 23)


func _spawn_float(text: String, origin: Vector2, color: Color, font_size: int) -> void:
	var label := _label(root_control, text)
	label.position = origin
	label.size = Vector2(180, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("172142"))
	label.add_theme_constant_override("outline_size", 6)
	floating_entries.append({"label": label, "age": 0.0, "duration": 1.05})


func _build_result() -> void:
	result_shade = ColorRect.new()
	result_shade.color = Color(0.025, 0.035, 0.11, 0.76)
	result_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(result_shade)
	result_shade.hide()
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(32, 286)
	result_panel.size = Vector2(368, 374)
	var panel_style := _style(Color("29346d"), Color("8b8dff"), 5, 26)
	result_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(result_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	result_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)
	result_title = _label(stack, "")
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 34)
	result_title.add_theme_color_override("font_outline_color", Color("141a42"))
	result_title.add_theme_constant_override("outline_size", 5)
	result_stats = _label(stack, "")
	result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_stats.add_theme_font_size_override("font_size", 20)
	result_stats.add_theme_color_override("font_color", Color("f1f3ff"))
	var retry := Button.new()
	retry.name = "RetryButton"
	retry.text = "重试同一张城市"
	retry.custom_minimum_size = Vector2(0, 54)
	retry.add_theme_font_size_override("font_size", 21)
	_style_button(retry, Color("69cf45"), Color("c4ff6b"))
	retry.pressed.connect(func() -> void: retry_requested.emit())
	stack.add_child(retry)
	var home := Button.new()
	home.name = "HomeButton"
	home.text = "返回首页 · 新城市"
	home.custom_minimum_size = Vector2(0, 50)
	home.add_theme_font_size_override("font_size", 19)
	_style_button(home, Color("6255ba"), Color("b4a7ff"))
	home.pressed.connect(func() -> void: home_requested.emit())
	stack.add_child(home)
	result_panel.hide()


func _style(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


func _style_button(button: Button, color: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _style(color, border, 3, 16))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.10), Color.WHITE, 3, 16))
	button.add_theme_stylebox_override("pressed", _style(color.darkened(0.12), border, 3, 16))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color("24305b"))
	button.add_theme_constant_override("outline_size", 3)


func show_result(result: Dictionary) -> void:
	result_title.text = "抵达终点！" if result.victory else "本局失败"
	result_title.add_theme_color_override("font_color", Color("ffe34e") if result.victory else Color("ff8c9c"))
	result_stats.text = "完成度 %d%%\n目标分 %d · 金币 %d\n体型 %d · 击倒 %d" % [roundi(result.completion * 100), result.score, result.coins, result.level, result.knockdowns]
	result_shade.show()
	result_panel.show()
	result_panel.move_to_front()
