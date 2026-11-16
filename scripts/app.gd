class_name GameApp
extends Node

var home_screen: Control
var session: GameSession
var current_seed: int = -1
var _seed_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_seed_rng.randomize()
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


func start_session(seed_value: int = -1) -> void:
	if is_instance_valid(home_screen):
		home_screen.queue_free()
		home_screen = null
	if is_instance_valid(session):
		session.queue_free()
		session = null
	if seed_value < 0:
		seed_value = _seed_rng.randi_range(1, 2147483646)
		if seed_value == current_seed:
			seed_value += 1
	current_seed = seed_value
	session = load("res://scripts/gameplay/game_session.gd").new()
	session.seed_value = current_seed
	session.retry_requested.connect(retry_session)
	session.home_requested.connect(show_home)
	add_child(session)


func retry_session() -> void:
	start_session(current_seed)
