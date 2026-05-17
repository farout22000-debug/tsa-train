extends ColorRect

@onready var message_label = %MessageLabel
@onready var btn_return = %BtnReturn

func _ready() -> void:
	btn_return.pressed.connect(_on_return_pressed)
	hide()
	NetworkManager.client_disconnected.connect(_on_disconnected)

func _on_disconnected() -> void:
	if not multiplayer.is_server():
		show()

func _on_return_pressed() -> void:
	NetworkManager.stop_network()
	SceneTransition.change_scene_to_file("res://scenes/screens/login.tscn")
