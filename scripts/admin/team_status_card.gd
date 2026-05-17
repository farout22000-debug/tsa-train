extends PanelContainer

signal detailed_view_requested(team_id: int)

@onready var team_name_label = %TeamNameLabel
@onready var speed_label = %SpeedLabel
@onready var distance_label = %DistanceLabel
@onready var members_label = %MembersLabel
@onready var activity_rect = %ActivityRect

var my_team_id: int = 0

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(team_id: int) -> void:
	my_team_id = team_id
	team_name_label.text = "Team " + str(team_id)

func update_data(data: Dictionary) -> void:
	speed_label.text = NumberFormatter.format_value(data.speed, 1) + " km/h"
	distance_label.text = NumberFormatter.format_value(data.distance, 2) + " km"
	members_label.text = str(data.members.size()) + " Members"
	
	if data.speed > 50:
		activity_rect.color = Color(0.2, 1.0, 0.2) # Fast
	elif data.speed > 20:
		activity_rect.color = Color(1.0, 1.0, 0.2) # Moving
	else:
		activity_rect.color = Color(0.5, 0.5, 0.5) # Idle

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		detailed_view_requested.emit(my_team_id)
