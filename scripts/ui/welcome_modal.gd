extends Control

signal tutorial_started

@onready var lbl_welcome = %LblWelcome
@onready var lbl_team = %LblTeam
@onready var btn_start = %BtnStart

func _ready():
	hide()
	btn_start.pressed.connect(_on_start_pressed)

func open_modal(player_name: String, team_id: int):
	lbl_welcome.text = "Welcome Conductor " + player_name + "!"
	lbl_team.text = "[center]You have been assigned to [color=#ffd04d]Team " + str(team_id) + "[/color].\n\n" + \
		"Report your sales to increase the speed of your Team's Train!\n\n" + \
		"[color=#ff6666][b]Warning:[/b] This game is subject to TSA's Acceptable Use Policy, reporting of Sales is moderated and any mis-use may result in a ban from the game.[/color]\n\n" + \
		"Please report any bugs via the \"Report Bug\" button.[/center]"
	show()

func _on_start_pressed():
	tutorial_started.emit()
	hide()
