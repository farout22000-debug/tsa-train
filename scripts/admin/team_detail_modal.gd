extends ColorRect

@onready var close_btn = %BtnClose
@onready var title_label = %TitleLabel
@onready var members_vbox = %MembersVBox
@onready var logs_vbox = %LogsVBox

@onready var speed_input = %SpeedInput
@onready var btn_set_speed = %BtnSetSpeed
@onready var distance_input = %DistanceInput
@onready var btn_set_distance = %BtnSetDistance

var active_team_id: int = 0

func _ready() -> void:
	close_btn.pressed.connect(func(): hide())
	btn_set_speed.pressed.connect(_on_set_speed)
	btn_set_distance.pressed.connect(_on_set_distance)
	hide()

func open_for_team(team_id: int, team_data: Dictionary) -> void:
	active_team_id = team_id
	title_label.text = "Team " + str(team_id) + " Details"
	
	speed_input.text = ""
	distance_input.text = ""
	
	# Clear previous
	for child in members_vbox.get_children():
		child.queue_free()
	for child in logs_vbox.get_children():
		child.queue_free()
		
	# Populate members
	if team_data.has("members"):
		for email in team_data.members:
			var lbl = Label.new()
			lbl.text = "- " + email
			members_vbox.add_child(lbl)
		
	# Populate logs
	if team_data.has("logs"):
		for log_msg in team_data.logs:
			var lbl = Label.new()
			lbl.text = "> " + log_msg
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
			logs_vbox.add_child(lbl)
	
	show()

func _on_set_speed() -> void:
	if active_team_id > 0 and not speed_input.text.is_empty():
		var new_speed = speed_input.text.to_float()
		GameManager.admin_override_team(active_team_id, new_speed, -1.0)
		speed_input.text = ""

func _on_set_distance() -> void:
	if active_team_id > 0 and not distance_input.text.is_empty():
		var new_distance = distance_input.text.to_float()
		GameManager.admin_override_team(active_team_id, -1.0, new_distance)
		distance_input.text = ""

