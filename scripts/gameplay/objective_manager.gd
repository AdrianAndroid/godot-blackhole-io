class_name ObjectiveManager
extends RefCounted

signal changed
signal tower_unlock_requested

var target_score: int = 1
var current_score: int = 0
var coins: int = 0
var knockdowns: int = 0
var tower_unlocked: bool = false
var settled_ids: Dictionary = {}
var last_knockdown_time: float = -100.0
var multi_knockdown: int = 0
var match_time: float = 0.0
var multi_window: float = 4.0


func configure(ordinary_total_score: int) -> void:
	target_score = maxi(1, ceili(float(ordinary_total_score) * 0.75))


func completion() -> float:
	return clampf(float(current_score) / float(target_score), 0.0, 1.0)


func settle(event: Dictionary) -> bool:
	var object_id := int(event.get("object_id", -1))
	if settled_ids.has(object_id):
		return false
	settled_ids[object_id] = true
	var kind := str(event.get("kind", "normal"))
	if kind == "tower":
		changed.emit()
		return true
	current_score += int(event.get("score", 0))
	coins += int(event.get("coins", 0))
	if kind == "opponent":
		knockdowns += 1
		multi_knockdown = multi_knockdown + 1 if match_time - last_knockdown_time <= multi_window else 1
		last_knockdown_time = match_time
	if completion() >= 1.0 and not tower_unlocked:
		tower_unlocked = true
		tower_unlock_requested.emit()
	changed.emit()
	return true


func reset() -> void:
	current_score = 0
	coins = 0
	knockdowns = 0
	tower_unlocked = false
	settled_ids.clear()
	last_knockdown_time = -100.0
	multi_knockdown = 0
	match_time = 0.0
