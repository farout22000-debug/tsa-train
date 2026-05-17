extends CanvasLayer

@onready var container = %Container
@onready var btn_add_points = %BtnAddPoints
@onready var btn_wipe_save = %BtnWipeSave
@onready var btn_close = %BtnClose

func _ready():
	visible = false
	btn_add_points.pressed.connect(_on_add_points_pressed)
	btn_wipe_save.pressed.connect(_on_wipe_save_pressed)
	btn_close.pressed.connect(_on_close_pressed)

func open():
	visible = true

func _on_add_points_pressed():
	GameManager.add_action("admin_cheat")

func _on_wipe_save_pressed():
	GameManager.reset_game_data()
	visible = false

func _on_close_pressed():
	visible = false
