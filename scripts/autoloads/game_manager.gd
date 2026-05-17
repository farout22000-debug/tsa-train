extends Node

signal distance_changed(new_distance: float)
signal speed_changed(new_speed: float)
signal train_upgraded(level: int)
signal milestone_reached(event_name: String)
signal buff_started(buff_name: String, duration: float)
signal leaderboard_updated(data: Array)
signal logs_updated(logs: Array)
signal buttons_updated(buttons_list: Array)
signal tickets_changed(new_tickets: float)

const SAVE_PATH = "user://savegame.tres"
const SERVER_DATA_PATH = "user://server_teams.json"
const USERS_DATA_PATH = "user://server_users.json"
const BUTTONS_DATA_PATH = "user://server_buttons.json"
const BUGS_DATA_PATH = "user://server_bugs.json"

const DEFAULT_BUTTONS = [
	{"id": "car", "name": "Car", "value": 5.0, "announcement_template": "{player_name} Sold a {button_name}! (+{value} km/h)"},
	{"id": "home", "name": "Home", "value": 10.0, "announcement_template": "{player_name} Sold a {button_name}! (+{value} km/h)"},
	{"id": "ctp", "name": "CTP", "value": 15.0, "announcement_template": "{player_name} Sold a {button_name}! (+{value} km/h)"},
	{"id": "rsa", "name": "RSA", "value": 20.0, "announcement_template": "{player_name} Sold a {button_name}! (+{value} km/h)"},
	{"id": "renewal", "name": "Renewal", "value": 8.0, "announcement_template": "{player_name} Sold a {button_name}! (+{value} km/h)"}
]

var stats: PlayerStats
var active_milestone_config: MilestoneList

var server_teams: Dictionary = {}
var server_users: Dictionary = {}
var server_buttons: Array = []
var server_bugs: Dictionary = {}
var pending_registrations: Dictionary = {} # { email: { code: string, expires_at: float, data: Dictionary } }
var connected_peers: Dictionary = {} # { peer_id: email }

# CLIENT ADMIN ONLY: Cache of team states for the dashboard
var admin_teams: Dictionary = {}



# Array to hold active buffs (Dictionaries: { "team_id": 1, "action": "ALL", "multiplier": 2.0, "time_left": 10.0 })
var active_buffs: Array[Dictionary] = []

var leaderboard_sync_timer: float = 0.0
var save_timer: float = 0.0
var heartbeat_timer: float = 0.0

var _dirty_teams: bool = false
var _dirty_users: bool = false
var is_maintenance_mode: bool = false

var total_clicks_received: int = 0
var clicks_per_second: float = 0.0
var _click_accumulator: int = 0
var _throughput_timer: float = 0.0

var _peer_click_history: Dictionary = {}
var _peer_lockout_until: Dictionary = {}
const RATE_LIMIT_WINDOW: float = 2.0
const MAX_CLICKS_IN_WINDOW: int = 8
const LOCKOUT_DURATION: float = 5.0


func _ready():
	_init_default_milestones()
	load_game()
	
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_init_server_teams()
		_init_server_users()
		_init_server_bugs()
	elif not multiplayer.has_multiplayer_peer() and OS.has_feature("admin"):
		# If running standalone admin before hosting, initialize teams anyway
		_init_server_teams()
		_init_server_users()
		_init_server_bugs()
		
	_init_server_buttons()
	
	# Ensure signals fire initially
	call_deferred("emit_signal", "speed_changed", stats.current_speed)
	call_deferred("emit_signal", "distance_changed", stats.total_distance)
	
	if multiplayer:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		connected_peers.erase(id)
		_peer_click_history.erase(id)
		_peer_lockout_until.erase(id)

func _process(delta: float):
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return # Only server processes physics/time
		
	# SERVER / OFFLINE LOGIC
	
	# Process active buffs
	for i in range(active_buffs.size() - 1, -1, -1):
		active_buffs[i].time_left -= delta
		if active_buffs[i].time_left <= 0:
			active_buffs.remove_at(i)
			
	# Update all 10 teams
	if not server_teams.is_empty():
		for t_id in server_teams:
			var team = server_teams[t_id]
			var distance_delta = (team.speed / 3600.0) * delta
			team.distance += distance_delta
			
			# If offline (singleplayer), update local stats too
			if not multiplayer.has_multiplayer_peer() and stats.team_id == t_id:
				stats.total_distance = team.distance
				stats.current_speed = team.speed
				distance_changed.emit(stats.total_distance)
				
		# Periodic Syncing
		leaderboard_sync_timer += delta
		if leaderboard_sync_timer >= 1.0: # Sync every 1 sec
			leaderboard_sync_timer = 0.0
			_broadcast_state()
			_generate_and_broadcast_leaderboard()
			
		_throughput_timer += delta
		if _throughput_timer >= 1.0:
			clicks_per_second = float(_click_accumulator) / _throughput_timer
			if clicks_per_second > 500:
				if get_node_or_null("/root/AdminLogger"):
					get_node("/root/AdminLogger").log_event("THROUGHPUT WARNING: " + str(int(clicks_per_second)) + " clicks/sec", "SYSTEM")
			_click_accumulator = 0
			_throughput_timer = 0.0
			
		save_timer += delta
		if save_timer >= 2.0:
			save_timer = 0.0
			
			var current_time = Time.get_unix_time_from_system()
			for email in pending_registrations.keys():
				if current_time > pending_registrations[email].expires_at:
					pending_registrations.erase(email)
					
			if _dirty_teams:
				_flush_server_teams()
			if _dirty_users:
				_flush_server_users()
				
		heartbeat_timer += delta
		if heartbeat_timer >= 300.0:
			heartbeat_timer = 0.0
			if FileAccess.file_exists(SERVER_DATA_PATH):
				DirAccess.copy_absolute(SERVER_DATA_PATH, SERVER_DATA_PATH + ".bak")
			if FileAccess.file_exists(USERS_DATA_PATH):
				DirAccess.copy_absolute(USERS_DATA_PATH, USERS_DATA_PATH + ".bak")

			
	else:
		# Fallback if somehow no server teams but we are offline processing
		var distance_delta = (stats.current_speed / 3600.0) * delta
		stats.total_distance += distance_delta
		distance_changed.emit(stats.total_distance)

	_check_milestones()
	_check_upgrades()

# --- Server Team Management ---
func _init_server_teams():
	if FileAccess.file_exists(SERVER_DATA_PATH):
		var file = FileAccess.open(SERVER_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			# JSON keys are strings, convert to ints
			for k in json.data:
				server_teams[k.to_int()] = json.data[k]
		else:
			if FileAccess.file_exists(SERVER_DATA_PATH + ".bak"):
				var bak_file = FileAccess.open(SERVER_DATA_PATH + ".bak", FileAccess.READ)
				var bak_json = JSON.new()
				if bak_json.parse(bak_file.get_as_text()) == OK and bak_json.data is Dictionary:
					for k in bak_json.data:
						server_teams[k.to_int()] = bak_json.data[k]
					if get_node_or_null("/root/AdminLogger"):
						get_node("/root/AdminLogger").log_event("WARNING: Restored server_teams from backup.", "SYSTEM")
	
	# Ensure 15 teams exist
	for i in range(1, 16):
		if not server_teams.has(i):
			server_teams[i] = {"distance": 0.0, "speed": 20.0, "members": [], "logs": [], "milestones": []}

		else:
			if not server_teams[i].has("logs"):
				server_teams[i]["logs"] = []
			if not server_teams[i].has("milestones"):
				server_teams[i]["milestones"] = []

func _init_server_users():
	if FileAccess.file_exists(USERS_DATA_PATH):
		var file = FileAccess.open(USERS_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			server_users = json.data
		else:
			if FileAccess.file_exists(USERS_DATA_PATH + ".bak"):
				var bak_file = FileAccess.open(USERS_DATA_PATH + ".bak", FileAccess.READ)
				var bak_json = JSON.new()
				if bak_json.parse(bak_file.get_as_text()) == OK and bak_json.data is Dictionary:
					server_users = bak_json.data
					if get_node_or_null("/root/AdminLogger"):
						get_node("/root/AdminLogger").log_event("WARNING: Restored server_users from backup.", "SYSTEM")

func _save_server_users():
	_dirty_users = true

func _flush_server_users():
	var file = FileAccess.open(USERS_DATA_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(server_users))
	_dirty_users = false

func _init_server_buttons():
	if FileAccess.file_exists(BUTTONS_DATA_PATH):
		var file = FileAccess.open(BUTTONS_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Array:
			server_buttons = json.data
			return
			
	server_buttons = DEFAULT_BUTTONS.duplicate(true)
	_save_server_buttons()

func _save_server_buttons():
	var file = FileAccess.open(BUTTONS_DATA_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(server_buttons))

func _save_server_teams():
	_dirty_teams = true

func _flush_server_teams():
	var file = FileAccess.open(SERVER_DATA_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(server_teams))
	_dirty_teams = false


func _hash_password(password: String, salt: String) -> String:
	return (password + salt).sha256_text()

@rpc("any_peer", "call_remote", "reliable")
func request_register(player_name: String, email: String, team_id: int, password: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	if is_maintenance_mode and email != "daniel.young@tsagroup.com.au":
		auth_response.rpc_id(sender_id, false, "Server is currently under maintenance. Please try again later.", 0)
		return
		
	if server_users.has(email):
		auth_response.rpc_id(sender_id, false, "Email already registered.")
		return
		
	var salt = str(randi()) + str(Time.get_unix_time_from_system())
	var hash = _hash_password(password, salt)
	
	var assigned_role = "admin" if email == "daniel.young@tsagroup.com.au" else "player"
	
	# If 2FA is NOT required, register the user immediately
	if not ConfigManager.require_2fa:
		var user_data = {
			"name": player_name,
			"team_id": team_id,
			"role": assigned_role,
			"salt": salt,
			"hash": hash,
			"tickets": 0.0,
			"has_seen_tutorial": false,
			"action_counts": { "Car": 0, "Home": 0, "CTP": 0, "RSA": 0, "Renewal": 0 }
		}
		
		server_users[email] = user_data
		_save_server_users()
		
		if server_teams.has(team_id) and not email in server_teams[team_id].members:
			server_teams[team_id].members.append(email)
			_save_server_teams()
			
		connected_peers[sender_id] = email
		auth_response.rpc_id(sender_id, true, "Registration successful.", team_id, assigned_role, player_name, 0.0, false, user_data.action_counts)
		return
	
	var code = str(randi_range(100000, 999999))
	
	pending_registrations[email] = {
		"code": code,
		"expires_at": Time.get_unix_time_from_system() + 300, # 5 minutes
		"data": {
			"name": player_name,
			"team_id": team_id,
			"role": assigned_role,
			"salt": salt,
			"hash": hash,
			"tickets": 0.0,
			"has_seen_tutorial": false,
			"action_counts": { "Car": 0, "Home": 0, "CTP": 0, "RSA": 0, "Renewal": 0 }
		}
	}
	
	if get_node_or_null("/root/EmailManager"):
		get_node("/root/EmailManager").send_verification_email(email, code)
	else:
		print("[Server] EmailManager not found. Verification code for %s is: %s" % [email, code])
	
	auth_response.rpc_id(sender_id, false, "VERIFICATION_PENDING", 0, "player")

@rpc("any_peer", "call_remote", "reliable")
func verify_registration(email: String, code: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not pending_registrations.has(email):
		auth_response.rpc_id(sender_id, false, "No pending registration found.")
		return
		
	var pending = pending_registrations[email]
	
	if Time.get_unix_time_from_system() > pending.expires_at:
		pending_registrations.erase(email)
		auth_response.rpc_id(sender_id, false, "Code expired. Please register again.")
		return
		
	if pending.code != code:
		auth_response.rpc_id(sender_id, false, "Invalid verification code.")
		return
		
	# Success
	var user_data = pending.data
	var team_id = user_data.team_id
	
	server_users[email] = user_data
	pending_registrations.erase(email)
	_save_server_users()
	
	if server_teams.has(team_id) and not email in server_teams[team_id].members:
		server_teams[team_id].members.append(email)
		_save_server_teams()
	
	connected_peers[sender_id] = email
	auth_response.rpc_id(sender_id, true, "Registration successful.", team_id, user_data.role, user_data.name, user_data.get("tickets", 0.0), user_data.get("has_seen_tutorial", false), user_data.get("action_counts", {}))


@rpc("any_peer", "call_remote", "reliable")
func request_login(email: String, password: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not server_users.has(email):
		auth_response.rpc_id(sender_id, false, "Email not found.", 0)
		return
		
	var user = server_users[email]
	
	if user.has("is_banned") and user.is_banned:
		auth_response.rpc_id(sender_id, false, "Your account has been deactivated.", 0)
		return
		
	var role = user.get("role", "player")
	if email == "daniel.young@tsagroup.com.au": role = "admin" # Fallback auto-upgrade
	
	if is_maintenance_mode and role != "admin":
		auth_response.rpc_id(sender_id, false, "Server is currently under maintenance. Please try again later.", 0)
		return
		
	var test_hash = _hash_password(password, user.salt)

	
	if test_hash == user.hash:
		connected_peers[sender_id] = email
		auth_response.rpc_id(sender_id, true, "Login successful.", user.team_id, role, user.get("name", "Unknown"), user.get("tickets", 0.0), user.get("has_seen_tutorial", false), user.get("action_counts", {}))
	else:
		auth_response.rpc_id(sender_id, false, "Incorrect password.", 0, "player")

@rpc("any_peer", "call_remote", "reliable")
func sync_progress_to_server(tickets: float, has_seen_tutorial: bool, action_counts: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if connected_peers.has(sender_id):
		var email = connected_peers[sender_id]
		if server_users.has(email):
			var user = server_users[email]
			user["tickets"] = tickets
			user["has_seen_tutorial"] = has_seen_tutorial
			user["action_counts"] = action_counts
			_save_server_users()

@rpc("authority", "call_remote", "reliable")
func auth_response(success: bool, message: String, team_id: int, role: String = "player", player_name: String = "", tickets: float = 0.0, has_seen_tutorial: bool = false, action_counts: Dictionary = {}):
	EventBus.auth_result.emit(success, message, team_id, role, player_name, tickets, has_seen_tutorial, action_counts)
	if success:
		stats.role = role
		if not player_name.is_empty():
			stats.player_name = player_name



func _broadcast_state():
	if not multiplayer.has_multiplayer_peer(): return
	
	var admin_payload = {}
	for t_id in server_teams:
		var t = server_teams[t_id]
		sync_team_state.rpc(t_id, t.distance, t.speed)
		admin_payload[t_id] = {
			"distance": t.distance,
			"speed": t.speed,
			"members": t.members
		}
		
	sync_admin_state.rpc(admin_payload)


func _generate_and_broadcast_leaderboard():
	var lb = []
	for t_id in server_teams:
		var t = server_teams[t_id]
		if t.members.size() > 0:
			var member_count = t.members.size()
			lb.append({"name": "Team " + str(t_id) + " (" + str(member_count) + " Drivers)", "score": t.distance})
	
	lb.sort_custom(func(a, b): return a.score > b.score)
	
	if multiplayer.has_multiplayer_peer():
		sync_leaderboard.rpc(lb)
	else:
		leaderboard_updated.emit(lb)

# --- Client Sync Receivers ---
@rpc("authority", "call_remote", "unreliable")
func sync_team_state(team_id: int, distance: float, speed: float):
	if stats and stats.team_id == team_id:
		stats.total_distance = distance
		stats.current_speed = speed
		distance_changed.emit(stats.total_distance)
		speed_changed.emit(stats.current_speed)

@rpc("authority", "call_remote", "unreliable")
func sync_admin_state(payload: Dictionary):
	if stats and stats.role == "admin":
		admin_teams = payload


@rpc("authority", "call_remote", "reliable")
func sync_leaderboard(data: Array) -> void:
	leaderboard_updated.emit(data)

@rpc("authority", "call_remote", "reliable")
func sync_announcement(message: String):
	EventBus.announcement_requested.emit(message)

@rpc("authority", "call_remote", "reliable")
func sync_team_logs(team_id: int, logs: Array):
	if stats and stats.team_id == team_id:
		logs_updated.emit(logs)

@rpc("any_peer", "call_remote", "reliable")
func request_rehydration(team_id: int):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if server_teams.has(team_id):
		var t = server_teams[team_id]
		sync_team_state.rpc_id(sender_id, team_id, t.distance, t.speed)
		sync_team_logs.rpc_id(sender_id, team_id, t.logs)
		
		# Sync milestones
		if t.has("milestones"):
			for m in t.milestones:
				sync_milestone.rpc_id(sender_id, team_id, m)
		
		# Also send buffs
		for buff in active_buffs:
			if buff.team_id == team_id:
				sync_buff.rpc_id(sender_id, buff.action, buff.multiplier, buff.time_left)
				
		# Sync dynamic buttons
		sync_buttons.rpc_id(sender_id, server_buttons)


@rpc("authority", "call_remote", "reliable")
func sync_buttons(buttons_list: Array):
	server_buttons = buttons_list
	buttons_updated.emit(server_buttons)

@rpc("authority", "call_remote", "reliable")
func sync_buff(action_name: String, multiplier: float, duration: float):
	buff_started.emit(action_name + " " + str(multiplier) + "x", duration)

func _log_team_event(team_id: int, message: String):
	if not server_teams.has(team_id): return
	var t = server_teams[team_id]
	t.logs.append(message)
	if t.logs.size() > 20:
		t.logs.pop_front()
	_save_server_teams()
	if multiplayer.has_multiplayer_peer():
		sync_team_logs.rpc(team_id, t.logs)
	else:
		if stats and stats.team_id == team_id:
			logs_updated.emit(t.logs)


# --- Core Logic ---
func _init_default_milestones() -> void:
	active_milestone_config = MilestoneList.new()
	var m1 = Milestone.new()
	m1.type = Milestone.MilestoneType.SPEED
	m1.threshold = 80 
	m1.event_name = "unlock_steam"
	active_milestone_config.milestones.append(m1)
	
	var m2 = Milestone.new()
	m2.type = Milestone.MilestoneType.SPEED
	m2.threshold = 1000 # Threshold in km/h
	m2.event_name = "reach_space"
	active_milestone_config.milestones.append(m2)



func get_save_path() -> String:
	if stats and not stats.email.is_empty():
		var safe_email = stats.email.to_lower().replace("@", "_").replace(".", "_")
		return "user://savegame_" + safe_email + ".tres"
	return "user://savegame.tres"

func load_game() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		stats = ResourceLoader.load(SAVE_PATH) as PlayerStats
	if not stats:
		stats = PlayerStats.new()

func load_account_game(email: String) -> void:
	var path = "user://savegame_" + email.to_lower().replace("@", "_").replace(".", "_") + ".tres"
	if ResourceLoader.exists(path):
		stats = ResourceLoader.load(path) as PlayerStats
	else:
		stats = PlayerStats.new()
		stats.email = email
	save_game()

func save_game() -> void:
	if stats:
		ResourceSaver.save(stats, get_save_path())

func reset_game_data() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	stats = PlayerStats.new()
	if SceneTransition:
		SceneTransition.change_scene_to_file("res://scenes/screens/login.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/screens/login.tscn")

func get_player_name() -> String:
	return stats.player_name

func get_distance() -> float:
	return stats.total_distance
	
func get_speed() -> float:
	return stats.current_speed

func get_train_level() -> int:
	return stats.train_level

func set_player_name(new_name: String) -> void:
	stats.player_name = new_name
	save_game()

func get_multiplier(team_id: int, action_name: String) -> float:
	var multiplier = 1.0
	for buff in active_buffs:
		if buff.team_id == team_id and (buff.action == action_name or buff.action == "ALL"):
			multiplier *= buff.multiplier
	return multiplier

func add_buff(team_id: int, action_name: String, multiplier: float, duration: float) -> void:
	active_buffs.append({
		"team_id": team_id,
		"action": action_name,
		"multiplier": multiplier,
		"time_left": duration
	})
	if stats.team_id == team_id:
		buff_started.emit(action_name + " " + str(multiplier) + "x", duration)

func add_action(action_id: String) -> void:
	if stats:
		stats.add_action(action_id)
		tickets_changed.emit(stats.total_tickets)
		if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
			sync_progress_to_server.rpc_id(1, stats.total_tickets, stats.has_seen_tutorial, stats.action_counts)

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_action.rpc_id(1, action_id) 
	else:
		_process_action_on_server(multiplayer.get_unique_id(), stats.team_id, stats.email, stats.player_name, action_id)

@rpc("any_peer", "call_remote", "reliable")
func request_action(action_id: String) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	var current_time = Time.get_unix_time_from_system()
	if _peer_lockout_until.has(sender_id) and current_time < _peer_lockout_until[sender_id]:
		return # Locked out
		
	# Security check: verify email and peer identity
	var email = ""
	var team_id = 0
	var player_name = ""
	if connected_peers.has(sender_id):
		email = connected_peers[sender_id]
		if server_users.has(email):
			team_id = server_users[email].get("team_id", 0)
			player_name = server_users[email].get("name", "Unknown")
			
	if email == "" or team_id == 0:
		return # Unknown sender or user
		
	if not _peer_click_history.has(sender_id):
		_peer_click_history[sender_id] = []
		
	var history: Array = _peer_click_history[sender_id]
	var valid_history: Array = []
	for t in history:
		if current_time - t <= RATE_LIMIT_WINDOW:
			valid_history.append(t)
			
	if valid_history.size() >= MAX_CLICKS_IN_WINDOW:
		_peer_lockout_until[sender_id] = current_time + LOCKOUT_DURATION
		var msg = "SUSPECTED BOTTING: peer %d (%s) exceeded rate limit. Locked out for %ds." % [sender_id, email, LOCKOUT_DURATION]
		if get_node_or_null("/root/AdminLogger"):
			get_node("/root/AdminLogger").log_event(msg, "SECURITY")
		print("[Server] " + msg)
		return
		
	valid_history.append(current_time)
	_peer_click_history[sender_id] = valid_history
	
	total_clicks_received += 1
	_click_accumulator += 1
	
	_process_action_on_server(sender_id, team_id, email, player_name, action_id)

func _process_action_on_server(sender_id: int, team_id: int, email: String, player_name: String, action_id: String) -> void:
	if not server_teams.has(team_id): return
	
	var btn_data = null
	if action_id == "admin_cheat":
		btn_data = {"id": "admin_cheat", "name": "Admin Cheat", "value": 10.0, "announcement_template": "{player_name} triggered Admin Cheat! (+{value} km/h)"}
	else:
		for btn in server_buttons:
			if btn.id == action_id:
				btn_data = btn
				break
	if btn_data == null: return
	
	var base_speed_increase = float(btn_data.value)
	var action_name = btn_data.name
	var template = btn_data.announcement_template
	
	# Register member if new
	var team = server_teams[team_id]
	if not email in team.members:
		team.members.append(email)
		
	var multiplier = 1.0
	for buff in active_buffs:
		if buff.team_id == team_id and (buff.action == action_id or buff.action == action_name or buff.action == "ALL"):
			multiplier *= buff.multiplier
			
	var actual_increase = base_speed_increase * multiplier
	team.speed += actual_increase
	
	# Format message using interpolation
	var msg = template
	msg = msg.replace("{player_name}", player_name)
	msg = msg.replace("{button_name}", action_name)
	msg = msg.replace("{value}", str(snapped(actual_increase, 0.1)))
	
	_log_team_event(team_id, msg)
	
	if multiplayer.has_multiplayer_peer():
		sync_announcement.rpc(msg)
	else:
		EventBus.announcement_requested.emit(msg)
	
	if action_id == "rsa" or action_name == "RSA":
		add_buff(team_id, "ctp", 2.0, 120.0)
		var buff_msg = "VIP Boarded! CTP boost 2x for 2 mins!"
		_log_team_event(team_id, buff_msg)
		if multiplayer.has_multiplayer_peer():
			sync_announcement.rpc(buff_msg)
		else:
			EventBus.announcement_requested.emit(buff_msg)

	_save_server_teams()


# --- Admin Overrides ---
func is_admin(peer_id: int) -> bool:
	if peer_id == 1: return true # Local server is admin
	if not connected_peers.has(peer_id): return false
	var email = connected_peers[peer_id]
	if not server_users.has(email): return false
	var role = server_users[email].get("role", "player")
	return role == "admin" or email == "daniel.young@tsagroup.com.au"

@rpc("any_peer", "call_remote", "reliable")
func admin_update_buttons(new_buttons_list: Array) -> void:
	if not multiplayer.is_server():
		admin_update_buttons.rpc_id(1, new_buttons_list)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	server_buttons = new_buttons_list
	_save_server_buttons()
	sync_buttons.rpc(server_buttons)
	
	var admin_email = connected_peers.get(sender_id, "Unknown")
	var msg = "ADMIN '%s' updated button configurations." % [admin_email]
	if get_node_or_null("/root/AdminLogger"):
		get_node("/root/AdminLogger").log_event(msg, "ADMIN")
	print("[Server] " + msg)

@rpc("any_peer", "call_remote", "reliable")
func set_maintenance_mode(active: bool) -> void:
	if not multiplayer.is_server():
		set_maintenance_mode.rpc_id(1, active)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	is_maintenance_mode = active
	var msg = "ADMIN: Maintenance Mode " + ("ENABLED" if active else "DISABLED")
	if get_node_or_null("/root/AdminLogger"):
		get_node("/root/AdminLogger").log_event(msg, "ADMIN")
	if multiplayer.has_multiplayer_peer():
		sync_announcement.rpc(msg)

@rpc("any_peer", "call_remote", "reliable")
func reset_simulation() -> void:
	if not multiplayer.is_server():
		reset_simulation.rpc_id(1)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return


	
	for t_id in server_teams:
		server_teams[t_id].distance = 0.0
		server_teams[t_id].speed = 20.0
		server_teams[t_id].logs.clear()
		server_teams[t_id].milestones.clear()
		
	_flush_server_teams()
	_broadcast_state()

	
	if multiplayer.has_multiplayer_peer():
		sync_simulation_reset.rpc()
		sync_announcement.rpc("Simulation has been reset by Admin.")
	else:
		sync_simulation_reset()
	print("[Server] Simulation data reset. Users preserved.")

@rpc("authority", "call_remote", "reliable")
func sync_simulation_reset() -> void:
	if stats:
		stats.total_tickets = 0.0
		stats.total_distance = 0.0
		stats.current_speed = 20.0
		stats.train_level = 1
		for action in stats.action_counts:
			stats.action_counts[action] = 0
		save_game()
		
		distance_changed.emit(stats.total_distance)
		speed_changed.emit(stats.current_speed)
		tickets_changed.emit(stats.total_tickets)

@rpc("any_peer", "call_remote", "reliable")
func update_user_admin(email: String, new_team_id: int, new_name: String, is_banned: bool) -> void:
	if not multiplayer.is_server():
		update_user_admin.rpc_id(1, email, new_team_id, new_name, is_banned)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return

	
	if server_users.has(email):

		var old_team = server_users[email].team_id
		server_users[email].team_id = new_team_id
		server_users[email].name = new_name
		server_users[email].is_banned = is_banned
		_save_server_users()
		
		# Move roster if team changed
		if old_team != new_team_id:
			if server_teams.has(old_team):
				server_teams[old_team].members.erase(email)
			if server_teams.has(new_team_id) and not email in server_teams[new_team_id].members:
				server_teams[new_team_id].members.append(email)

@rpc("any_peer", "call_remote", "reliable")
func delete_user_admin(email: String, delete_sales: bool) -> void:
	if not multiplayer.is_server():
		delete_user_admin.rpc_id(1, email, delete_sales)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	if server_users.has(email):
		var team_id = server_users[email].team_id
		server_users.erase(email)
		
		# Remove from team roster
		if server_teams.has(team_id):
			server_teams[team_id].members.erase(email)
			
		_save_server_users()
		
		# Optionally delete their sales save file
		if delete_sales:
			var save_path = "user://savegame_" + email.to_lower().replace("@", "_").replace(".", "_") + ".tres"
			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(save_path)
				print("[Admin] Deleted sales file for user: ", email)
				
		# Broadcast refreshed users list to the requesting admin
		var safe_users = {}
		for e in server_users:
			var u = server_users[e].duplicate()
			if u.has("password_hash"): u.erase("password_hash")
			if u.has("password_salt"): u.erase("password_salt")
			safe_users[e] = u
		sync_users_to_admin.rpc_id(sender_id, safe_users)

@rpc("any_peer", "call_remote", "reliable")
func reset_user_password_admin(email: String, new_password_plain: String) -> void:
	if not multiplayer.is_server():
		reset_user_password_admin.rpc_id(1, email, new_password_plain)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	if server_users.has(email):
		var salt = str(randi()) + str(Time.get_unix_time_from_system())
		var hash = _hash_password(new_password_plain, salt)
		server_users[email].password_hash = hash
		server_users[email].password_salt = salt
		_save_server_users()
		
		# Log the event
		var admin_email = connected_peers.get(sender_id, "Unknown")
		var msg = "ADMIN '%s' reset password for '%s'" % [admin_email, email]
		if get_node_or_null("/root/AdminLogger"):
			get_node("/root/AdminLogger").log_event(msg, "SECURITY")
		print("[Server] " + msg)
		_flush_server_teams()


@rpc("any_peer", "call_remote", "reliable")
func wipe_all_data() -> void:
	if not multiplayer.is_server():
		wipe_all_data.rpc_id(1)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return

	
	# Hidden factory reset

	server_teams.clear()
	server_users.clear()
	server_bugs.clear()
	if FileAccess.file_exists(SERVER_DATA_PATH):
		DirAccess.remove_absolute(SERVER_DATA_PATH)
	if FileAccess.file_exists(USERS_DATA_PATH):
		DirAccess.remove_absolute(USERS_DATA_PATH)
	if FileAccess.file_exists(BUGS_DATA_PATH):
		DirAccess.remove_absolute(BUGS_DATA_PATH)
	_init_server_teams()
	_init_server_users()
	_init_server_bugs()
	_broadcast_state()
	print("[Server] Factory reset complete.")

@rpc("any_peer", "call_remote", "reliable")
func admin_override_team(team_id: int, new_speed: float, new_distance: float) -> void:
	if not multiplayer.is_server():
		admin_override_team.rpc_id(1, team_id, new_speed, new_distance)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return

	
	if server_teams.has(team_id):

		var t = server_teams[team_id]
		if new_speed >= 0:
			t.speed = new_speed
		if new_distance >= 0:
			t.distance = new_distance
		
		_flush_server_teams()
		_broadcast_state()

		
		var msg = "ADMIN: Stats manually adjusted. (Speed: " + str(t.speed) + ", Distance: " + str(t.distance) + ")"
		_log_team_event(team_id, msg)
		if multiplayer.has_multiplayer_peer():
			sync_announcement.rpc(msg)

@rpc("any_peer", "call_remote", "reliable")
func admin_set_speed(new_speed: float) -> void:
	if not multiplayer.is_server():
		admin_set_speed.rpc_id(1, new_speed)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return

	
	for t_id in server_teams:

		server_teams[t_id].speed = new_speed
	_broadcast_state()
	AdminLogger.log_event("Admin set global speed to " + str(new_speed), "ADMIN")

@rpc("any_peer", "call_remote", "reliable")
func admin_give_tickets(amount: float) -> void:
	if not multiplayer.is_server():
		admin_give_tickets.rpc_id(1, amount)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return

	
	stats.total_tickets += amount
	tickets_changed.emit(stats.total_tickets)

	save_game()
	AdminLogger.log_event("Admin gave " + str(amount) + " global tickets", "ADMIN")

@rpc("any_peer", "call_remote", "reliable")
func admin_send_message(message: String) -> void:
	if not multiplayer.is_server():
		admin_send_message.rpc_id(1, message)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return

	
	EventBus.announcement_requested.emit("[SERVER] " + message)

	if multiplayer.has_multiplayer_peer():
		sync_announcement.rpc("[SERVER] " + message)
	AdminLogger.log_event("Admin broadcast: " + message, "ADMIN")

func _check_milestones() -> void:
	if not active_milestone_config: return
	
	# SERVER SIDE: Check per team
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		for t_id in server_teams:
			var team = server_teams[t_id]
			for m in active_milestone_config.milestones:
				var current_val = team.distance if m.type == Milestone.MilestoneType.DISTANCE else team.speed
				if current_val >= m.threshold and not m.event_name in team.milestones:
					team.milestones.append(m.event_name)
					sync_milestone.rpc(t_id, m.event_name)
	
	# CLIENT SIDE (Singleplayer or local tracking)
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		for m in active_milestone_config.milestones:
			var current_val = stats.total_distance if m.type == Milestone.MilestoneType.DISTANCE else stats.current_speed
			if current_val >= m.threshold and not stats.has_unlocked(m.event_name):
				stats.unlock_event(m.event_name)
				milestone_reached.emit(m.event_name)


@rpc("authority", "call_remote", "reliable")
func sync_milestone(team_id: int, event_name: String):
	if stats and stats.team_id == team_id:
		if not stats.has_unlocked(event_name):
			stats.unlock_event(event_name)
			milestone_reached.emit(event_name)


func _check_upgrades() -> void:
	pass

# --- Bug Reporting System ---
func _init_server_bugs() -> void:
	if FileAccess.file_exists(BUGS_DATA_PATH):
		var file = FileAccess.open(BUGS_DATA_PATH, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			server_bugs = json.data

func _save_server_bugs() -> void:
	var file = FileAccess.open(BUGS_DATA_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(server_bugs, "\t"))
	file.close()

func _broadcast_bugs_to_admins() -> void:
	for peer_id in connected_peers:
		if is_admin(peer_id):
			sync_bugs_to_admin.rpc_id(peer_id, server_bugs)

@rpc("any_peer", "call_remote", "reliable")
func submit_bug_report(category: String, description: String, os_name: String) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if not connected_peers.has(sender_id): return
	
	var email = connected_peers[sender_id]
	var team_id = server_users[email].get("team_id", 0) if server_users.has(email) else 0
	
	var bug_id = "BUG_" + str(Time.get_ticks_msec()) + "_" + str(randi_range(100, 999))
	
	server_bugs[bug_id] = {
		"id": bug_id,
		"email": email,
		"team_id": team_id,
		"category": category,
		"description": description.strip_edges(),
		"status": "Open",
		"timestamp": Time.get_unix_time_from_system(),
		"os": os_name
	}
	_save_server_bugs()
	
	submit_bug_response.rpc_id(sender_id, true, "Bug report submitted successfully!")
	_broadcast_bugs_to_admins()

@rpc("authority", "call_remote", "reliable")
func submit_bug_response(success: bool, message: String) -> void:
	EventBus.emit_signal("bug_submit_result", success, message)

@rpc("any_peer", "call_remote", "reliable")
func request_bugs_list() -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	sync_bugs_to_admin.rpc_id(sender_id, server_bugs)

@rpc("authority", "call_remote", "reliable")
func sync_bugs_to_admin(bugs: Dictionary) -> void:
	EventBus.emit_signal("bugs_sync_received", bugs)

@rpc("any_peer", "call_remote", "reliable")
func request_users_list() -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	# Strip password credentials before transmitting for security
	var safe_users = {}
	for email in server_users:
		var u = server_users[email].duplicate()
		if u.has("password_hash"): u.erase("password_hash")
		if u.has("password_salt"): u.erase("password_salt")
		safe_users[email] = u
		
	sync_users_to_admin.rpc_id(sender_id, safe_users)

@rpc("authority", "call_remote", "reliable")
func sync_users_to_admin(users: Dictionary) -> void:
	server_users = users
	EventBus.emit_signal("users_sync_received", users)

@rpc("any_peer", "call_remote", "reliable")
func admin_update_bug_status(bug_id: String, new_status: String) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	if server_bugs.has(bug_id):
		server_bugs[bug_id]["status"] = new_status
		_save_server_bugs()
		_broadcast_bugs_to_admins()

@rpc("any_peer", "call_remote", "reliable")
func admin_delete_bug(bug_id: String) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	if server_bugs.has(bug_id):
		server_bugs.erase(bug_id)
		_save_server_bugs()
		_broadcast_bugs_to_admins()

# --- Stealth 2FA Toggle RPCs ---

@rpc("authority", "call_remote", "reliable")
func log_admin_event_to_client(msg: String, category: String = "INFO"):
	if stats and stats.role == "admin":
		if get_node_or_null("/root/AdminLogger"):
			get_node("/root/AdminLogger").log_event(msg, category)

@rpc("any_peer", "call_remote", "reliable")
func toggle_2fa_admin():
	if not multiplayer.is_server():
		toggle_2fa_admin.rpc_id(1)
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	ConfigManager.require_2fa = not ConfigManager.require_2fa
	ConfigManager.save_config()
	
	var state_str = "ENABLED" if ConfigManager.require_2fa else "DISABLED"
	var msg = "SECURITY: 2FA verification for new registrations has been stealth-%s." % [state_str]
	
	if get_node_or_null("/root/AdminLogger"):
		get_node("/root/AdminLogger").log_event(msg, "ADMIN")
	print("[Server] " + msg)
	
	log_admin_event_to_client.rpc_id(sender_id, msg, "SECURITY")

@rpc("any_peer", "call_remote", "reliable")
func request_2fa_status():
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if not is_admin(sender_id): return
	
	var state_str = "ENABLED" if ConfigManager.require_2fa else "DISABLED"
	var msg = "System: 2FA verification is currently %s." % [state_str]
	log_admin_event_to_client.rpc_id(sender_id, msg, "SECURITY")
