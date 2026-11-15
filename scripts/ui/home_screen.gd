class_name HomeScreen
extends Control

signal start_requested


func _ready() -> void:
	name = "HomeScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101a2e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	var title := Label.new()
	title.text = "黑洞城市"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "第 1 关 · 适中"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	column.add_child(subtitle)

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.text = "开始对局"
	start_button.custom_minimum_size = Vector2(240, 64)
	start_button.add_theme_font_size_override("font_size", 24)
	start_button.pressed.connect(func() -> void: start_requested.emit())
	column.add_child(start_button)

	var hint := Label.new()
	hint.text = "拖动摇杆移动 · 吞噬城市 · 完成目标"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)
