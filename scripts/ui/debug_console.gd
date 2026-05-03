extends CanvasLayer

@onready var line_edit = %LineEdit
@onready var container = %Container

var admin_menu_scene = preload("res://scenes/ui/admin_menu.tscn")
var admin_menu_instance = null

func _ready():
	container.visible = false
	line_edit.text_submitted.connect(_on_text_submitted)
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_console"):
		_toggle_console()

func _toggle_console():
	container.visible = not container.visible
	if container.visible:
		line_edit.grab_focus()
		line_edit.clear()

func _on_text_submitted(new_text: String):
	if new_text.strip_edges() == "wingus":
		_open_admin_menu()
	
	line_edit.clear()
	_toggle_console()

func _open_admin_menu():
	if not admin_menu_instance:
		admin_menu_instance = admin_menu_scene.instantiate()
		get_tree().root.add_child(admin_menu_instance)
	
	admin_menu_instance.open()
