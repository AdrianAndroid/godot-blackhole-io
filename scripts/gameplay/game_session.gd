class_name GameSession
extends Node3D

enum State { HOME, READY, PLAYING, PAUSED, RESULT }

signal finished(result: Dictionary)
signal retry_requested
signal home_requested

const MATCH_DURATION: float = 600.0
const ADVANTAGE: float = 1.10
const OPPONENT_COLORS: Array[Color] = [Color("a56eff"), Color("ff8b38"), Color("45d69b"), Color("ff4e62")]

var seed_value: int = 1
var state: State = State.READY
var automatic: bool = true
var driver_enabled: bool = false
var drive_input := Vector2.ZERO
var remaining_time: float = MATCH_DURATION
var result: Dictionary = {}
var event_log: Array[Dictionary] = []

var generator := CityGenerator.new()
var layout: CityGenerator.Layout
var spawn_manager: SpawnManager
var swallow_manager: SwallowManager
var growth := GrowthManager.new()
var objective := ObjectiveManager.new()
var player: HoleActor
var opponents: Array[RouteOpponent] = []
var tower: Swallowable
var player_death_target: Swallowable
var camera_rig: FollowCamera
var input_controller: InputController
var hud: HudController
var audio: AudioManager
var attraction_bursts: Array[AttractionBurst] = []
var attraction_pool: Array[AttractionBurst] = []
var _completed_events: Array[Dictionary] = []


func _ready() -> void:
	name = "Session"
	_build()


func _build() -> void:
	layout = generator.generate(seed_value)
	objective.configure(layout.ordinary_total_score)
	objective.tower_unlock_requested.connect(_spawn_tower)
	spawn_manager = SpawnManager.new()
	add_child(spawn_manager)
	spawn_manager.build(layout)
	swallow_manager = SwallowManager.new()
	add_child(swallow_manager)
	swallow_manager.claimed.connect(_on_swallow_claimed)
	swallow_manager.completed.connect(_queue_completed)
	player = HoleActor.new()
	player.name = "Player"
	player.map_size = layout.map_size
	player.position = layout.player_spawn
	player.effective_radius = growth.radius
	add_child(player)
	for index in 4:
		var opponent := RouteOpponent.new()
		opponent.name = "Opponent_%d" % (index + 1)
		opponent.setup_route(2000 + index, layout.opponent_radii[index], OPPONENT_COLORS[index], layout.routes[index])
		add_child(opponent)
		opponents.append(opponent)
	camera_rig = FollowCamera.new()
	camera_rig.map_size = layout.map_size
	add_child(camera_rig)
	camera_rig.snap(player.position, player.effective_radius)
	var input_layer := CanvasLayer.new()
	input_layer.layer = 5
	add_child(input_layer)
	input_controller = InputController.new()
	input_layer.add_child(input_controller)
	hud = HudController.new()
	hud.layer = 10
	add_child(hud)
	hud.retry_requested.connect(func() -> void: retry_requested.emit())
	hud.home_requested.connect(func() -> void: home_requested.emit())
	audio = AudioManager.new()
	add_child(audio)
	for index in 12:
		var effect := AttractionBurst.new()
		effect.prepare()
		add_child(effect)
		attraction_pool.append(effect)
	begin()


func begin() -> void:
	if state == State.READY:
		state = State.PLAYING
		input_controller.enabled = true
		hud.show_message("吞噬小物体，扩大黑洞")
		_update_hud()
		_record("match_started", {"seed": seed_value, "signature": layout.signature})


func _physics_process(delta: float) -> void:
	if automatic:
		_step_gameplay(delta)


func _process(delta: float) -> void:
	var finishing_camera := state == State.RESULT and camera_rig != null and camera_rig.finale_active and camera_rig.finale_blend < 1.0
	if automatic and (state == State.PLAYING or finishing_camera):
		_step_presentation(delta)


# Manual tests and replay drivers advance both layers explicitly. Production
# physics and rendering call the two layers independently at their own cadence.
func step(delta: float) -> void:
	if state != State.PLAYING:
		return
	_step_gameplay(delta)
	_step_presentation(delta)


func _step_gameplay(delta: float) -> void:
	if state != State.PLAYING:
		return
	remaining_time = maxf(0.0, remaining_time - delta)
	objective.match_time += delta
	var direction := drive_input if driver_enabled else input_controller.input_vector
	for object in spawn_manager.dynamic_objects:
		if is_instance_valid(object):
			object.advance_route(delta, false)
	if player.alive:
		player.step(delta, direction)
	for opponent in opponents:
		opponent.step_route(delta)
	if player.alive:
		_check_swallow_contacts()
	swallow_manager.step(delta)
	_process_completed_events()


func _step_presentation(delta: float) -> void:
	player.visual.step(delta)
	for opponent in opponents:
		opponent.actor.visual.step(delta)
	for index in range(attraction_bursts.size() - 1, -1, -1):
		var effect := attraction_bursts[index]
		effect.step(delta)
		if effect.finished():
			effect.release()
			attraction_pool.append(effect)
			attraction_bursts.remove_at(index)
	hud.step(delta)
	spawn_manager.advance_visuals(delta, player.position, player.effective_radius)
	camera_rig.step(delta, player.position, player.effective_radius)
	var camera := camera_rig.orthographic_camera if camera_rig.projection == "orthographic" else camera_rig.perspective_camera
	for object in spawn_manager.dynamic_objects:
		if is_instance_valid(object):
			object.advance_animation_frame(delta, camera)
	_update_hud()


func _on_swallow_claimed(object: Swallowable, hole: HoleActor) -> void:
	hole.visual.trigger_pulse(0.5)
	if object.kind == "tower" and hole == player:
		camera_rig.set_finale(true)
		camera_rig.add_shake(0.08)
		hud.show_message("终点塔下沉中…")
		_record("tower_swallow_started", {"position": object.position})
	if object.kind in ["normal", "opponent"]:
		var effect: AttractionBurst
		if attraction_pool.is_empty():
			effect = AttractionBurst.new()
			effect.prepare()
			add_child(effect)
		else:
			effect = attraction_pool.pop_back()
		effect.setup(object.global_position, hole, hole.faction_color)
		attraction_bursts.append(effect)


func _check_swallow_contacts() -> void:
	for object in spawn_manager.objects.values():
		if not is_instance_valid(object) or object.state != Swallowable.State.IDLE:
			continue
		if object.kind == "normal" or object.kind == "tower":
			swallow_manager.try_claim(object, player)
	for opponent in opponents:
		if opponent.state != Swallowable.State.IDLE:
			continue
		var distance := Vector2(opponent.position.x - player.position.x, opponent.position.z - player.position.z).length()
		if player.effective_radius >= opponent.footprint_radius * ADVANTAGE:
			if distance <= player.effective_radius + opponent.footprint_radius * 0.25:
				swallow_manager.try_claim(opponent, player)
		elif opponent.footprint_radius >= player.effective_radius * ADVANTAGE:
			if distance <= opponent.footprint_radius + player.effective_radius * 0.25:
				_begin_player_death(opponent)
				return


func _begin_player_death(opponent: RouteOpponent) -> void:
	if player_death_target != null or state != State.PLAYING:
		return
	player.alive = false
	player.visual.hide()
	input_controller.clear()
	var representation := HoleVisual.new()
	representation.effective_radius = player.effective_radius
	representation.faction_color = player.faction_color
	player_death_target = Swallowable.new()
	player_death_target.kind = "player"
	player_death_target.setup({"id": "player", "footprint_radius": player.effective_radius, "xp": 0, "score": 0, "coins": 0}, 900000, representation)
	player_death_target.position = player.position
	player_death_target.capture_transform()
	add_child(player_death_target)
	swallow_manager.try_claim(player_death_target, opponent.actor)
	_record("player_swallow_started", {"opponent": opponent.object_id})


func _queue_completed(event: Dictionary) -> void:
	_completed_events.append(event)


func _process_completed_events() -> void:
	var events := _completed_events.duplicate()
	_completed_events.clear()
	var player_died := false
	var tower_completed := false
	for event in events:
		if state != State.PLAYING:
			break
		match str(event.kind):
			"normal", "opponent":
				if objective.settle(event):
					var levels := growth.add_experience(int(event.xp))
					if not levels.is_empty():
						player.effective_radius = growth.radius
					player.visual.trigger_pulse(1.0)
					camera_rig.add_shake(0.10 if event.kind == "opponent" else 0.035)
					hud.show_devour(event, levels, _feedback_screen_position())
					if event.kind == "normal":
						spawn_manager.retire_normal(int(event.object_id))
					if event.kind == "opponent":
						audio.play("knockdown")
						hud.show_message("%d 连击！" % objective.multi_knockdown if objective.multi_knockdown >= 2 else "击倒对手 +%d 目标分" % int(event.score))
						_record("knockdown", event)
					else:
						audio.play("devour")
						_record("object_settled", event)
					if not levels.is_empty():
						audio.play("level_up")
						hud.show_message("体型提升 · Lv.%d" % growth.level)
						_record("level_up", {"level": growth.level, "radius": growth.radius})
			"player":
				player_died = true
			"tower":
				tower_completed = true
	# Same-tick priority is explicit: death > tower victory > timeout.
	if player_died:
		_finish(false, "swallowed")
	elif tower_completed:
		_finish(true, "tower")
	elif remaining_time <= 0.0:
		_finish(false, "timeout")


func _feedback_screen_position() -> Vector2:
	var camera := camera_rig.orthographic_camera if camera_rig.projection == "orthographic" else camera_rig.perspective_camera
	return camera.unproject_position(player.global_position + Vector3(0, 0.4, 0))


func _spawn_tower() -> void:
	if tower != null or state != State.PLAYING:
		return
	tower = spawn_manager.spawn_tower(layout.tower_position)
	audio.play("tower_spawn")
	hud.show_message("终点塔已解锁 · 完成度 100%")
	_record("tower_spawned", {"position": tower.position})


func pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	input_controller.clear()
	input_controller.enabled = false
	hud.show_message("已暂停 · 按 Esc 继续")
	_record("paused")


func resume() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	input_controller.enabled = true
	hud.show_message("继续对局")
	_record("resumed")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if state == State.PLAYING:
				pause()
			elif state == State.PAUSED:
				resume()
		elif event.keycode == KEY_C and state == State.PLAYING:
			toggle_projection()
		elif event.keycode == KEY_M:
			audio.muted = not audio.muted
			if audio.muted:
				audio.stop_all()


func toggle_projection() -> void:
	camera_rig.set_projection("orthographic" if camera_rig.projection == "perspective" else "perspective")
	_record("projection", {"mode": camera_rig.projection})


func _finish(victory: bool, reason: String) -> void:
	if state != State.PLAYING:
		return
	state = State.RESULT
	swallow_manager.cancel_all()
	input_controller.clear()
	input_controller.enabled = false
	result = {
		"victory": victory,
		"reason": reason,
		"seed": seed_value,
		"signature": layout.signature,
		"score": objective.current_score,
		"coins": objective.coins,
		"knockdowns": objective.knockdowns,
		"completion": objective.completion(),
		"level": growth.level,
		"remaining": remaining_time
	}
	audio.play("victory" if victory else "defeat")
	hud.show_result(result)
	_record("match_finished", result)
	finished.emit(result)


func _update_hud() -> void:
	if hud == null:
		return
	hud.update_values({"score": objective.current_score, "target": objective.target_score, "remaining": remaining_time, "level": growth.level, "experience": growth.experience, "coins": objective.coins, "completion": objective.completion(), "knockdowns": objective.knockdowns})
	if tower != null and tower.state != Swallowable.State.SETTLED:
		var offset := tower.position - player.position
		var horizontal := "东" if offset.x >= 0 else "西"
		var vertical := "南" if offset.z >= 0 else "北"
		hud.set_tower_direction("终点塔 · %s%s %dm" % [vertical, horizontal, roundi(offset.length())])


func living_opponents() -> int:
	var count := 0
	for opponent in opponents:
		if opponent.state != Swallowable.State.SETTLED:
			count += 1
	return count


func snapshot() -> Dictionary:
	return {
		"seed": seed_value,
		"generation_version": CityGenerator.GENERATION_VERSION,
		"signature": layout.signature,
		"state": state,
		"remaining": snappedf(remaining_time, 0.0001),
		"score": objective.current_score,
		"target": objective.target_score,
		"coins": objective.coins,
		"knockdowns": objective.knockdowns,
		"completion": snappedf(objective.completion(), 0.0001),
		"level": growth.level,
		"experience": growth.experience,
		"radius": snappedf(player.effective_radius, 0.0001),
		"player_position": [snappedf(player.position.x, 0.0001), snappedf(player.position.z, 0.0001)],
		"objects_remaining": spawn_manager.objects.size(),
		"living_opponents": living_opponents(),
		"tower_spawned": tower != null,
		"result": result
	}


func _record(type: String, data: Dictionary = {}) -> void:
	event_log.append({"time": snappedf(objective.match_time, 0.001), "type": type, "data": data.duplicate(true)})
	if event_log.size() > 300:
		event_log.pop_front()
