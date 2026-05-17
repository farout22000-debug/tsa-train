extends CanvasLayer

@onready var row_container = %RowContainer
@onready var btn_close = %BtnClose
@export var row_scene: PackedScene

func _ready():
	visible = false
	btn_close.pressed.connect(hide_leaderboard)
	GameManager.leaderboard_updated.connect(_on_leaderboard_updated)

func show_leaderboard():
	visible = true

func hide_leaderboard():
	visible = false

func _on_leaderboard_updated(data: Array):
	# Clear existing
	for child in row_container.get_children():
		child.queue_free()
		
	var rank = 1
	for entry in data:
		var row = row_scene.instantiate()
		row_container.add_child(row)
		row.setup(rank, entry.name, entry.score)
		rank += 1
