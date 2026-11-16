class_name SwallowManager
extends Node

signal claimed(object: Swallowable, hole: HoleActor)
signal completed(event: Dictionary)
signal cancelled(object_id: int)

var transactions: Dictionary = {}
var accept_claims: bool = true


static func qualifies(hole_radius: float, object_radius: float) -> bool:
	return object_radius < hole_radius


func try_claim(object: Swallowable, hole: HoleActor) -> bool:
	if not accept_claims or not is_instance_valid(object) or not is_instance_valid(hole):
		return false
	if object.state != Swallowable.State.IDLE:
		return false
	if object.kind == "normal" and not qualifies(hole.effective_radius, object.footprint_radius):
		return false
	if object.kind == "opponent" and hole.effective_radius < object.footprint_radius * 1.10:
		return false
	var object_position: Vector3 = object.global_position if object.is_inside_tree() else object.position
	var hole_position: Vector3 = hole.global_position if hole.is_inside_tree() else hole.position
	if Vector2(object_position.x - hole_position.x, object_position.z - hole_position.z).length() > hole.effective_radius + object.footprint_radius * 0.25:
		return false
	if not object.claim(hole.get_instance_id()):
		return false
	transactions[object.object_id] = {"object": object, "hole": hole}
	object.begin_sinking()
	claimed.emit(object, hole)
	return true


func step(delta: float) -> void:
	for object_id in transactions.keys().duplicate():
		var transaction: Dictionary = transactions.get(object_id, {})
		if transaction.is_empty():
			continue
		var object = transaction.get("object")
		var hole = transaction.get("hole")
		if not is_instance_valid(object) or not is_instance_valid(hole) or not hole.alive:
			if is_instance_valid(object):
				object.cancel()
				cancelled.emit(object_id)
			transactions.erase(object_id)
			continue
		var hole_position: Vector3 = hole.global_position if hole.is_inside_tree() else hole.position
		if object.advance(delta, hole_position):
			transactions.erase(object_id)
			completed.emit({
				"object_id": object.object_id,
				"model_id": object.model_id,
				"kind": object.kind,
				"xp": object.xp,
				"score": object.score,
				"coins": object.coins,
				"owner_id": object.claimed_by,
				"position": object.position
			})


func cancel_object(object_id: int) -> void:
	var transaction: Dictionary = transactions.get(object_id, {})
	if not transaction.is_empty():
		if is_instance_valid(transaction.object):
			transaction.object.cancel()
		transactions.erase(object_id)
		cancelled.emit(object_id)


func cancel_all() -> void:
	accept_claims = false
	for object_id in transactions.keys().duplicate():
		cancel_object(object_id)
