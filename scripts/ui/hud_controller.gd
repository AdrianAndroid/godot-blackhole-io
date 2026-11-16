class_name HudController
extends CanvasLayer

signal retry_requested
signal home_requested

var root_control: Control
var score_label: Label
var time_label: Label
var level_label: Label
var coins_label: Label
var message_label: Label
var objective_label: Label
var direction_label: Label
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
	theme.default_font = load("res://assets/game/fonts/NotoSansSC-Variable.ttf")
	theme.default_font_size = 18
	root_control.theme = theme
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 14)
	panel.size = Vector2(408, 106)
	root_control.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stack.add_child(row)
	score_label = _label(row, "目标 0/1")
	time_label = _label(row, "10:00")
	level_label = _label(row, "体型 1")
	coins_label = _label(row, "金币 0")
	objective_label = _label(stack, "完成度 0% · 吞噬城市，解锁金色高塔")
	objective_label.add_theme_font_size_override("font_size", 14)
	message_label = _label(root_control, "")
	message_label.position = Vector2(26, 142)
	message_label.size = Vector2(380, 54)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color("ffe178"))
	direction_label = _label(root_control, "")
	direction_label.position = Vector2(26, 196)
	direction_label.size = Vector2(380, 36)
	direction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_rects = [Rect2(panel.position, panel.size), Rect2(message_label.position, message_label.size), Rect2(direction_label.position, direction_label.size)]
	_build_result()


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func update_values(values: Dictionary) -> void:
	last_values = values.duplicate()
	score_label.text = "目标 %d/%d" % [values.score, values.target]
	time_label.text = "%02d:%02d" % [int(values.remaining) / 60, int(values.remaining) % 60]
	level_label.text = "最大体型" if values.level == 19 else "体型 %d" % values.level
	coins_label.text = "金币 %d" % values.coins
	objective_label.text = "完成度 %d%% · 击倒 %d" % [roundi(values.completion * 100.0), values.knockdowns]


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
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(38, 300)
	result_panel.size = Vector2(356, 310)
	root_control.add_child(result_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	result_panel.add_child(stack)
	result_title = _label(stack, "")
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 32)
	result_stats = _label(stack, "")
	result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var retry := Button.new()
	retry.name = "RetryButton"
	retry.text = "重试同一张城市"
	retry.pressed.connect(func() -> void: retry_requested.emit())
	stack.add_child(retry)
	var home := Button.new()
	home.name = "HomeButton"
	home.text = "返回首页 · 新城市"
	home.pressed.connect(func() -> void: home_requested.emit())
	stack.add_child(home)
	result_panel.hide()


func show_result(result: Dictionary) -> void:
	result_title.text = "胜利！" if result.victory else "本局失败"
	result_title.add_theme_color_override("font_color", Color("ffd95a") if result.victory else Color("ff7f89"))
	result_stats.text = "完成度 %d%%\n目标分 %d · 金币 %d\n体型 %d · 击倒 %d" % [roundi(result.completion * 100), result.score, result.coins, result.level, result.knockdowns]
	result_panel.show()
