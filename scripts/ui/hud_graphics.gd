class_name HudGraphics
extends Control

var remaining: float = 600.0
var completion: float = 0.0
var experience_progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_draw_timer()
	_draw_objective()
	_draw_coin()
	_draw_experience()


func _draw_timer() -> void:
	var center := Vector2(54, 53)
	draw_circle(center, 43.0, Color("20234f"))
	draw_arc(center, 41.0, 0.0, TAU, 80, Color("7079ff"), 6.0, true)
	draw_arc(center, 35.0, 0.0, TAU, 80, Color("111b42"), 7.0, true)
	var fraction := clampf(remaining / 600.0, 0.0, 1.0)
	draw_arc(center, 35.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, 80, Color("ffe33f"), 6.0, true)
	draw_circle(center, 29.0, Color("334ea1"))
	draw_arc(center, 29.0, 0.0, TAU, 64, Color("9bb8ff"), 2.0, true)


func _draw_objective() -> void:
	_capsule(Rect2(88, 24, 272, 58), Color("25224f"), Color("7582ff"), 5.0, 25.0)
	_capsule(Rect2(99, 34, 250, 38), Color("171b3e"), Color("3f4b98"), 2.0, 17.0)
	var width := 250.0 * clampf(completion, 0.0, 1.0)
	if width > 1.0:
		_capsule(Rect2(99, 34, maxf(width, 20.0), 38), Color("83ed24"), Color("c2ff56"), 2.0, 17.0)
	# A small destination flag remains legible even when the bar is empty.
	draw_line(Vector2(113, 43), Vector2(113, 63), Color("ecf4ff"), 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(115, 43), Vector2(130, 48), Vector2(115, 54)]), Color("ecf4ff"))
	_capsule(Rect2(106, 86, 216, 24), Color(0.09, 0.11, 0.25, 0.88), Color("626fb9"), 1.0, 11.0)


func _draw_coin() -> void:
	draw_circle(Vector2(385, 45), 18.0, Color("263268"))
	draw_circle(Vector2(385, 45), 13.0, Color("ffbd25"))
	draw_circle(Vector2(385, 45), 9.0, Color("ffe86a"))
	draw_line(Vector2(381, 39), Vector2(387, 37), Color("fff7c0"), 3.0, true)


func _draw_experience() -> void:
	_capsule(Rect2(126, 837, 246, 28), Color("201b43"), Color("7770e9"), 4.0, 13.0)
	var width := 234.0 * clampf(experience_progress, 0.0, 1.0)
	if width > 0.5:
		_capsule(Rect2(132, 843, maxf(width, 12.0), 16), Color("ffd632"), Color("fff078"), 1.0, 8.0)
	draw_circle(Vector2(130, 851), 16.0, Color("4b3d8c"))
	draw_circle(Vector2(130, 851), 11.0, Color("ffe147"))
	draw_line(Vector2(126, 851), Vector2(134, 851), Color("fff8c0"), 3.0, true)


func _capsule(rect: Rect2, color: Color, border: Color, border_width: int, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	draw_style_box(style, rect)
