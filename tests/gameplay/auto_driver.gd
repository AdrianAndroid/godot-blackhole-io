class_name AutoDriver
extends RefCounted

var avoid_all_opponents: bool = false
var mode: String = "victory"
var ticks: int = 0
var input_trace: Array[Dictionary] = []
var failure_label: String = ""
var failure_report: Dictionary = {}


func choose_input(session: GameSession) -> Vector2:
	var player_position := session.player.position
	if mode == "swallowed":
		var danger: RouteOpponent = null
		for opponent in session.opponents:
			if opponent.state != Swallowable.State.IDLE:
				continue
			if opponent.footprint_radius >= session.player.effective_radius * GameSession.ADVANTAGE:
				if danger == null or opponent.footprint_radius > danger.footprint_radius:
					danger = opponent
		if danger != null:
			var pursuit: Vector3 = danger.position - player_position
			return Vector2(pursuit.x, pursuit.z).normalized()
	for opponent in session.opponents:
		if opponent.state != Swallowable.State.IDLE:
			continue
		var dangerous: bool = opponent.footprint_radius >= session.player.effective_radius * GameSession.ADVANTAGE
		if dangerous or avoid_all_opponents:
			var away: Vector3 = player_position - opponent.position
			var avoidance_distance: float = 7.0 if dangerous else session.player.effective_radius + opponent.footprint_radius + 1.5
			if away.length() < avoidance_distance and away.length() > 0.001:
				return Vector2(away.x, away.z).normalized()
	if mode == "timeout":
		return Vector2.ZERO
	var target: Swallowable = null
	var best_distance := INF
	if session.tower != null and session.tower.state == Swallowable.State.IDLE:
		target = session.tower
	else:
		for object in session.spawn_manager.objects.values():
			if object.kind != "normal" or object.state != Swallowable.State.IDLE:
				continue
			if not SwallowManager.qualifies(session.player.effective_radius, object.footprint_radius):
				continue
			var distance: float = player_position.distance_to(object.position)
			if distance < best_distance:
				best_distance = distance
				target = object
	if target == null:
		return Vector2.ZERO
	var offset: Vector3 = target.position - player_position
	var distance := Vector2(offset.x, offset.z).length()
	if distance < 0.05:
		return Vector2.ZERO
	return Vector2(offset.x, offset.z).normalized() * clampf(distance / 0.6, 0.0, 1.0)


func run(session: GameSession, delta: float = 0.1, maximum_ticks: int = 6000) -> Dictionary:
	session.driver_enabled = true
	ticks = 0
	input_trace.clear()
	failure_report = {}
	while session.state == GameSession.State.PLAYING and ticks < maximum_ticks:
		session.drive_input = choose_input(session)
		input_trace.append({"tick": ticks, "input": [session.drive_input.x, session.drive_input.y]})
		session.step(delta)
		ticks += 1
	session.drive_input = Vector2.ZERO
	if session.state == GameSession.State.PLAYING:
		var label := failure_label if not failure_label.is_empty() else "driver_tick_limit_%d" % session.seed_value
		failure_report = FailureReporter.record(session, self, "driver_tick_limit", label, delta)
	return session.result
