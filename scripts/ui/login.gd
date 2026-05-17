extends Control

@onready var email_login = %EmailLogin
@onready var pass_login = %PassLogin
@onready var btn_login = %BtnLogin

@onready var name_reg = %NameReg
@onready var email_reg = %EmailReg
@onready var team_select = %TeamSelect
@onready var pass_reg = %PassReg
@onready var btn_register = %BtnRegister

@onready var remember_me_toggle = %RememberMeToggle
@onready var error_label = %ErrorLabel

@onready var verification_panel = %VerificationPanel
@onready var code_input = %CodeInput
@onready var btn_verify = %BtnVerify
@onready var btn_cancel_verify = %BtnCancelVerify

var is_registering = false
var fetched_tunnel_url: String = ""
var is_trying_fallback: bool = false

func _ready():
	if "--server" in OS.get_cmdline_args() or OS.has_feature("dedicated_server"):
		print("[Server Bootstrap] Starting dedicated server in headless mode...")
		NetworkManager.host_game(8090)
		hide()
		return

	btn_login.pressed.connect(_on_login_pressed)
	btn_register.pressed.connect(_on_register_pressed)

	
	NetworkManager.client_connected.connect(_on_client_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	EventBus.auth_result.connect(_on_auth_result)
	
	btn_verify.pressed.connect(_on_verify_pressed)
	btn_cancel_verify.pressed.connect(_on_cancel_verify_pressed)
	verification_panel.hide()
	
	# DiscoveryService is deprecated in Phase 11
	# DiscoveryService.discovery_complete.connect(_on_discovery_complete)
	# DiscoveryService.discovery_failed.connect(_on_discovery_failed)
	
	btn_login.disabled = false
	btn_register.disabled = false
	
	# Use Permanent Tunnel URL immediately
	fetched_tunnel_url = ConfigManager.PERMANENT_TUNNEL_URL
	
	# Populate team dropdown
	for i in range(1, 16):
		team_select.add_item("Team " + str(i), i - 1)
		
	# Pre-fill remembered user details
	if GameManager.stats:
		if not GameManager.stats.player_name.is_empty():
			name_reg.text = GameManager.stats.player_name
		if not GameManager.stats.email.is_empty():
			email_login.text = GameManager.stats.email
			email_reg.text = GameManager.stats.email
			remember_me_toggle.button_pressed = true
		if GameManager.stats.team_id > 0 and GameManager.stats.team_id <= 15:
			team_select.select(GameManager.stats.team_id - 1)

# _on_discovery_complete and _on_discovery_failed are no longer needed


func _validate_inputs() -> bool:
	error_label.text = ""
	
	var email = email_reg.text.strip_edges().to_lower() if is_registering else email_login.text.strip_edges().to_lower()
	var entered_code = pass_reg.text.strip_edges() if is_registering else pass_login.text.strip_edges()
	
	if is_registering:
		var player_name = name_reg.text.strip_edges()
		if player_name.is_empty():
			error_label.text = "Error: Conductor ID required for registration."
			return false
		
	if email.is_empty():
		error_label.text = "Error: Email required."
		return false
		
	var email_regex = RegEx.new()
	email_regex.compile("^[a-zA-Z0-9_\\.-]+\\.[a-zA-Z0-9_\\.-]+@tsagroup\\.com\\.au$")
	if not email_regex.search(email):
		error_label.text = "Error: Must use firstname.lastname@tsagroup.com.au"
		return false
		
	if entered_code.length() < 4:
		error_label.text = "Error: Password must be at least 4 characters."
		return false
		
	return true

func _on_login_pressed():
	is_registering = false
	if _validate_inputs():
		_start_connection()

func _on_register_pressed():
	is_registering = true
	if _validate_inputs():
		_start_connection()

func _start_connection():
	if fetched_tunnel_url.is_empty():
		error_label.text = "Cannot connect: No Tunnel URL."
		return
		
	is_trying_fallback = false
	btn_login.disabled = true
	btn_register.disabled = true
	error_label.text = "Connecting via Tunnel..."
	
	var error = NetworkManager.join_game(fetched_tunnel_url)
	if error != OK:
		error_label.text = "Error: Could not initialize network."
		btn_login.disabled = false
		btn_register.disabled = false

func _on_client_connected():
	error_label.text = "Authenticating..."
	
	if is_registering:
		var player_name = name_reg.text.strip_edges()
		var email = email_reg.text.strip_edges().to_lower()
		var password = pass_reg.text.strip_edges()
		var team_id = team_select.get_selected_id() + 1
		GameManager.request_register.rpc_id(1, player_name, email, team_id, password)
	else:
		var email = email_login.text.strip_edges().to_lower()
		var password = pass_login.text.strip_edges()
		GameManager.request_login.rpc_id(1, email, password)

func _on_auth_result(success: bool, message: String, team_id: int, role: String = "player", player_name: String = "", tickets: float = 0.0, has_seen_tutorial: bool = false, action_counts: Dictionary = {}):
	if success:
		var email = email_reg.text.strip_edges().to_lower() if is_registering else email_login.text.strip_edges().to_lower()
		
		# Load the user-specific save state (tickets, tutorials, etc.)
		GameManager.load_account_game(email)
		
		# Overwrite/sync with authoritative server state
		GameManager.stats.total_tickets = tickets
		GameManager.stats.has_seen_tutorial = has_seen_tutorial
		if not action_counts.is_empty():
			GameManager.stats.action_counts = action_counts
		
		# Handle Remember Me pre-fill cache (saved to user://savegame.tres)
		var cache = PlayerStats.new()
		if remember_me_toggle.button_pressed:
			cache.email = email
			cache.player_name = player_name if not player_name.is_empty() else GameManager.stats.player_name
		else:
			cache.email = ""
			cache.player_name = ""
		ResourceSaver.save(cache, GameManager.SAVE_PATH)
		
		# Update active user session variables
		GameManager.stats.role = role
		if not player_name.is_empty():
			GameManager.stats.player_name = player_name
		GameManager.stats.team_id = team_id
		GameManager.save_game() # Saves specifically to user://savegame_email.tres
		
		SceneTransition.change_scene_to_file("res://scenes/screens/main.tscn")
	elif message == "VERIFICATION_PENDING":
		_show_verification_panel()
	else:
		error_label.text = "Auth Failed: " + message
		if verification_panel.visible:
			btn_verify.disabled = false
		else:
			multiplayer.multiplayer_peer = null
			btn_login.disabled = false
			btn_register.disabled = false

func _show_verification_panel():
	verification_panel.show()
	code_input.text = ""
	error_label.text = "Check your email for the 6-digit code."
	btn_verify.disabled = false

func _on_verify_pressed():
	var code = code_input.text.strip_edges()
	if code.length() != 6:
		error_label.text = "Code must be 6 digits."
		return
		
	var email = email_reg.text.strip_edges().to_lower()
	btn_verify.disabled = true
	error_label.text = "Verifying..."
	GameManager.verify_registration.rpc_id(1, email, code)

func _on_cancel_verify_pressed():
	verification_panel.hide()
	multiplayer.multiplayer_peer = null
	btn_login.disabled = false
	btn_register.disabled = false
	error_label.text = ""

func _on_connection_failed():
	if not is_trying_fallback:
		is_trying_fallback = true
		error_label.text = "Tunnel failed. Trying local backup..."
		print("[Login] Tunnel connection failed. Attempting localhost fallback...")
		# Clean up failed peer before retry
		NetworkManager.stop_network()
		await get_tree().create_timer(1.0).timeout
		NetworkManager.join_game("ws://127.0.0.1:8090")
	else:
		error_label.text = "Error: Could not connect to Tunnel or Localhost."
		btn_login.disabled = false
		btn_register.disabled = false
