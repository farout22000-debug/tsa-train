extends Control

@onready var name_input = %NameInput
@onready var passcode_input = %PasscodeInput
@onready var remember_me_toggle = %RememberMeToggle
@onready var error_label = %ErrorLabel
@onready var connect_button = %ConnectButton

const PASSCODE = "TSA2026"
const AUTH_FILE = "user://authorized.json"

func _ready():
	connect_button.pressed.connect(_on_connect_pressed)
	
	# Check if already authorized
	if FileAccess.file_exists(AUTH_FILE):
		# Pre-fill name if we want, or just skip login if they already have a save game
		passcode_input.text = PASSCODE
		remember_me_toggle.button_pressed = true
		
	# If player has a name saved, pre-fill it
	if GameManager.stats and not GameManager.stats.player_name.is_empty():
		name_input.text = GameManager.stats.player_name

func _on_connect_pressed():
	error_label.text = ""
	var player_name = name_input.text.strip_edges()
	var entered_code = passcode_input.text.strip_edges()
	
	if player_name.is_empty():
		error_label.text = "Error: Conductor ID required."
		return
		
	if entered_code != PASSCODE:
		error_label.text = "Error: Invalid Authorization Code."
		return
	
	if remember_me_toggle.button_pressed:
		var file = FileAccess.open(AUTH_FILE, FileAccess.WRITE)
		file.store_string("authorized=true")
		file.close()
	else:
		if FileAccess.file_exists(AUTH_FILE):
			DirAccess.remove_absolute(AUTH_FILE)
	
	GameManager.set_player_name(player_name)
	SceneTransition.change_scene_to_file("res://scenes/screens/main.tscn")
