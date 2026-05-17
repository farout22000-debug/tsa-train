extends Control

const TeamCard = preload("res://scenes/ui/team_status_card.tscn")

@onready var btn_host = $VBoxContainer/HBoxContainer/BtnHost
@onready var btn_console = $VBoxContainer/HBoxContainer/BtnConsole
@onready var port_input = $VBoxContainer/HBoxContainer/PortInput
@onready var tunnel_input = %TunnelInput
@onready var status_label = $VBoxContainer/StatusLabel
@onready var team_grid = $VBoxContainer/TeamGrid
@onready var admin_console = $AdminConsole
@onready var team_detail_modal = $TeamDetailModal
@onready var btn_manage_users = $VBoxContainer/HBoxContainer/BtnManageUsers
@onready var user_management_panel = $UserManagementPanel
@onready var btn_wipe_all = $VBoxContainer/HBoxContainer/BtnWipeAll
@onready var btn_stress_test = %BtnStressTest
@onready var stress_test_panel = $StressTestPanel
@onready var btn_buttons_customizer = %BtnButtonsCustomizer
@onready var button_customizer_panel = $ButtonCustomizerPanel
@onready var btn_bugs = %BtnBugs
@onready var bug_reports_panel = $BugReportsPanel

@onready var wipe_dialog = $WipeDialog
@onready var title_label = $VBoxContainer/Label

var cards: Dictionary = {}


func _ready():
	if title_label:
		title_label.mouse_filter = Control.MOUSE_FILTER_STOP
		title_label.gui_input.connect(_on_title_gui_input)
		
	if multiplayer.has_multiplayer_peer():
		GameManager.request_2fa_status.rpc_id(1)
		
	btn_host.pressed.connect(_on_host_pressed)
	btn_console.pressed.connect(_on_console_pressed)
	NetworkManager.server_started.connect(_on_server_started)
	NetworkManager.peer_connected_to_server.connect(_on_peer_connected)
	
	# Initialize 15 cards
	for i in range(1, 16):
		var card = TeamCard.instantiate()
		team_grid.add_child(card)
		card.setup(i)
		card.detailed_view_requested.connect(_on_card_clicked)
		cards[i] = card
		
	btn_manage_users.pressed.connect(func(): user_management_panel.open_panel())
	btn_wipe_all.pressed.connect(func(): wipe_dialog.popup_centered())
	wipe_dialog.confirmed.connect(_on_wipe_confirmed)
	

	
	btn_stress_test.pressed.connect(func(): stress_test_panel.open_panel())
	btn_buttons_customizer.pressed.connect(func(): button_customizer_panel.open_panel())
	btn_bugs.pressed.connect(func(): bug_reports_panel.open_panel())
	
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		btn_host.hide()
		port_input.hide()
		tunnel_input.hide()
		status_label.text = "Status: Connected to Dedicated Server (Admin)"
	else:
		%BtnClose.hide()
		
	%BtnClose.pressed.connect(func(): queue_free())

	# Bind ControlTower size dynamically to the viewport size for perfect centering
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_wipe_confirmed():
	GameManager.reset_simulation()
	get_tree().reload_current_scene()


func _process(_delta: float):
	if GameManager.stats and GameManager.stats.role == "admin":
		for t_id in GameManager.admin_teams:
			if cards.has(t_id):
				cards[t_id].update_data(GameManager.admin_teams[t_id])


func _on_card_clicked(team_id: int):
	if GameManager.admin_teams.has(team_id):
		team_detail_modal.open_for_team(team_id, GameManager.admin_teams[team_id])


func _on_console_pressed():
	if admin_console:
		admin_console.show_console()

func _on_host_pressed():
	var port = port_input.text.to_int()
	if port <= 0: port = 8090
	NetworkManager.host_game(port)
	
	# Phase 11: Publishing is deprecated
	# if not tunnel_url.is_empty():
	# 	DiscoveryService.publish_tunnel_url(tunnel_url)

func _on_server_started():
	status_label.text = "Status: Hosting on Port " + port_input.text
	btn_host.disabled = true

func _on_peer_connected(id: int):
	print("[ControlTower] Peer connected: ", id)

func _on_title_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if multiplayer.has_multiplayer_peer():
			GameManager.toggle_2fa_admin.rpc_id(1)

func _on_viewport_size_changed():
	size = get_viewport_rect().size
	# Propagate size to child panels so they scale and center correctly even when opened from a hidden state
	if has_node("TeamDetailModal"): $TeamDetailModal.size = size
	if has_node("UserManagementPanel"): $UserManagementPanel.size = size
	if has_node("StressTestPanel"): $StressTestPanel.size = size
	if has_node("ButtonCustomizerPanel"): $ButtonCustomizerPanel.size = size
	if has_node("BugReportsPanel"): $BugReportsPanel.size = size
