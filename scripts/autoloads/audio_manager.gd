extends Node

# Use load() instead of preload() to avoid compile-time import errors
var sound_paths = {
	"click_light": "res://assets/audio/click_light.wav",
	"click_heavy": "res://assets/audio/click_heavy.wav",
	"hover": "res://assets/audio/hover.wav",
	"select": "res://assets/audio/select.wav"
}

var sounds = {}
var pool_size = 8
var pool = []
var next_player_idx = 0

func _ready():
	# Load sounds at runtime
	for key in sound_paths:
		var path = sound_paths[key]
		if FileAccess.file_exists(path):
			sounds[key] = load(path)
		else:
			push_warning("Audio file missing: " + path)

	# Create a pool of AudioStreamPlayers
	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		add_child(player)
		pool.append(player)

func play(sound_name: String, pitch_min: float = 0.9, pitch_max: float = 1.1):
	if not sounds.has(sound_name):
		return

	var player = pool[next_player_idx]
	player.stream = sounds[sound_name]
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()
	
	next_player_idx = (next_player_idx + 1) % pool_size

func play_click(points: int):
	if points >= 3:
		play("click_heavy")
	else:
		play("click_light")
