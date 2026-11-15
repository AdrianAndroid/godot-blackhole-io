class_name GameApp
extends Node

var home_screen: Control
var session: Node3D


func _ready() -> void:
	show_home()


func show_home() -> void:
	if is_instance_valid(session):
		session.queue_free()
		session = null
	if is_instance_valid(home_screen):
		home_screen.queue_free()
	home_screen = load("res://scripts/ui/home_screen.gd").new()
	home_screen.start_requested.connect(start_session)
	add_child(home_screen)


func start_session(_seed_value: int = -1) -> void:
	if is_instance_valid(home_screen):
		home_screen.queue_free()
		home_screen = null
	if is_instance_valid(session):
		session.queue_free()
	session = load("res://scripts/gameplay/game_session.gd").new()
	add_child(session)
