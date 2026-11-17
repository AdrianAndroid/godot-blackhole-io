class_name AudioManager
extends Node

const CUES := {
	"devour": "res://assets/game/audio/devour.ogg",
	"devour_large": "res://assets/game/audio/devour_large.ogg",
	"devour_fence": "res://assets/game/audio/devour_fence.ogg",
	"level_up": "res://assets/game/audio/level_up.ogg",
	"knockdown": "res://assets/game/audio/knockdown.ogg",
	"tower_spawn": "res://assets/game/audio/tower_spawn.ogg",
	"victory": "res://assets/game/audio/victory.ogg",
	"defeat": "res://assets/game/audio/defeat.ogg",
	"city_ambience": "res://assets/game/audio/city_ambience.ogg",
	"hole_move": "res://assets/game/audio/hole_move.ogg",
	"water_ambience": "res://assets/game/audio/water_ambience.ogg",
}
const LOOP_CUES: Array[String] = ["city_ambience", "hole_move", "water_ambience"]

var muted: bool = false
var volume_db: float = -12.0
var event_counts: Dictionary = {}
var active_players: Dictionary = {}
var streams: Dictionary = {}


func _ready() -> void:
	for cue in CUES:
		streams[cue] = load(CUES[cue])


func play(cue: String, pitch: float = 1.0) -> void:
	if not CUES.has(cue):
		return
	event_counts[cue] = int(event_counts.get(cue, 0)) + 1
	if muted:
		return
	var player := _player(cue)
	player.stream = streams[cue]
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.75, 1.35)
	player.stream_paused = false
	player.play()


func update_environment(movement: float, radius: float, water: float) -> void:
	if muted:
		stop_environment()
		return
	var growth := clampf((radius - 0.38) / 4.62, 0.0, 1.0)
	var motion := clampf(movement, 0.0, 1.0)
	_set_loop("city_ambience", volume_db - 14.0)
	_set_loop("hole_move", volume_db + lerpf(-48.0, -7.0, motion), 0.82 + growth * 0.38 + motion * 0.08)
	_set_loop("water_ambience", volume_db + lerpf(-44.0, -12.0, clampf(water, 0.0, 1.0)))


func pause_environment() -> void:
	for cue in LOOP_CUES:
		var player: AudioStreamPlayer = active_players.get(cue)
		if is_instance_valid(player):
			player.stream_paused = true


func resume_environment() -> void:
	if muted:
		return
	for cue in LOOP_CUES:
		var player: AudioStreamPlayer = active_players.get(cue)
		if is_instance_valid(player):
			player.stream_paused = false


func stop_environment() -> void:
	for cue in LOOP_CUES:
		var player: AudioStreamPlayer = active_players.get(cue)
		if is_instance_valid(player):
			player.stop()


func _player(cue: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = active_players.get(cue)
	if not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.name = cue.to_pascal_case()
		add_child(player)
		active_players[cue] = player
	return player


func _set_loop(cue: String, target_volume: float, pitch: float = 1.0) -> void:
	var player := _player(cue)
	if player.stream == null:
		var stream := streams[cue].duplicate() as AudioStreamOggVorbis
		stream.loop = true
		player.stream = stream
	player.volume_db = target_volume
	player.pitch_scale = pitch
	player.stream_paused = false
	if not player.playing:
		player.play()


func stop_all() -> void:
	for player in active_players.values():
		if is_instance_valid(player):
			player.stop()


func _exit_tree() -> void:
	stop_all()
	for player in active_players.values():
		if is_instance_valid(player):
			player.stream = null
	active_players.clear()
