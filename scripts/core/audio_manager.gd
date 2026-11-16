class_name AudioManager
extends Node

const CUES := {
	"devour": "res://assets/game/audio/devour.ogg",
	"level_up": "res://assets/game/audio/level_up.ogg",
	"knockdown": "res://assets/game/audio/knockdown.ogg",
	"tower_spawn": "res://assets/game/audio/tower_spawn.ogg",
	"victory": "res://assets/game/audio/victory.ogg",
	"defeat": "res://assets/game/audio/defeat.ogg"
}

var muted: bool = false
var volume_db: float = -12.0
var event_counts: Dictionary = {}
var active_players: Dictionary = {}
var streams: Dictionary = {}


func _ready() -> void:
	for cue in CUES:
		streams[cue] = load(CUES[cue])


func play(cue: String) -> void:
	if not CUES.has(cue):
		return
	event_counts[cue] = int(event_counts.get(cue, 0)) + 1
	if muted:
		return
	var player: AudioStreamPlayer = active_players.get(cue)
	if not is_instance_valid(player):
		player = AudioStreamPlayer.new()
		player.stream = streams[cue]
		add_child(player)
		active_players[cue] = player
	player.volume_db = volume_db
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
