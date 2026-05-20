extends Node2D

@onready var player_name_label = %PlayerNameLabel
@onready var score_label = %ScoreLabel
@onready var speed_label = %SpeedLabel
@onready var ticket_bin = %TicketBin
@onready var ticket_label = %TicketLabel
@onready var train_image = %TrainImage
@onready var steam_particles = %SteamParticles
@onready var log_scroll = %LogScroll
@onready var log_vbox = %LogVBox
@onready var sky_sprite = %SkySprite
@onready var track_sprite = %TrackSprite
@onready var camera = $Camera2D


const ClickBurst = preload("res://scenes/vfx/click_burst.tscn")
const GoldTicket = preload("res://scenes/vfx/gold_ticket.tscn")
const StarfieldTexture = preload("res://assets/sprites/starfield.jpg")
const SpaceTrackTexture = preload("res://assets/sprites/space_track.jpg")
const CloudsTexture = preload("res://assets/sprites/clouds_far.jpg")
const NormalTrackTexture = preload("res://assets/sprites/track.jpg")



@onready var action_buttons_container = %ActionButtonsContainer
@onready var btn_settings = %BtnSettings
@onready var btn_leaderboard = %BtnLeaderboard
@onready var btn_admin = %BtnAdmin
@onready var btn_report_bug = %BtnReportBug
@onready var welcome_modal = %WelcomeModal
@onready var bug_report_modal = %BugReportModal
@onready var settings_menu = %SettingsMenu
var tutorial_active: bool = false
var tutorial_tween: Tween

var time_passed: float = 0.0
var last_speed: float = 0.0
var is_server_connected: bool = true
var vibration_timer: float = 0.0
var current_vibration_offset: float = 0.0



func _ready():
	print("[Main] Initializing UI...")
	player_name_label.text = GameManager.get_player_name()
	print("[Main] Player name set")
	_update_score(GameManager.get_distance())
	_update_speed(GameManager.get_speed())
	_update_tickets()
	print("[Main] Labels updated")
	
	GameManager.distance_changed.connect(_on_distance_changed)
	GameManager.speed_changed.connect(_on_speed_changed)
	GameManager.tickets_changed.connect(_on_tickets_changed)
	GameManager.train_upgraded.connect(_on_train_upgraded)
	GameManager.milestone_reached.connect(_on_milestone_reached)
	if GameManager.has_signal("milestone_locked"):
		GameManager.milestone_locked.connect(_on_milestone_locked)
	GameManager.logs_updated.connect(_on_logs_updated)
	
	GameManager.buttons_updated.connect(rebuild_action_buttons)
	if not GameManager.server_buttons.is_empty():
		rebuild_action_buttons(GameManager.server_buttons)
	
	btn_settings.pressed.connect(func(): settings_menu.open_menu())
	btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
	btn_admin.pressed.connect(_on_admin_pressed)
	btn_report_bug.pressed.connect(_on_report_bug_pressed)
	
	if GameManager.stats and GameManager.stats.role == "admin":
		btn_admin.show()

	

	# Restore unlocked visual states
	for event in GameManager.stats.unlocked_events:
		_on_milestone_reached(event)
		
	# Request state rehydration from Server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		GameManager.request_rehydration.rpc_id(1, GameManager.stats.team_id)
		
	NetworkManager.client_disconnected.connect(_on_server_disconnected)
	
	if not GameManager.stats.has_seen_tutorial:
		welcome_modal.open_modal(GameManager.stats.player_name, GameManager.stats.team_id)
		welcome_modal.tutorial_started.connect(_start_tutorial_highlights)
	
	# Delay pivot setting to ensure layout is calculated
	call_deferred("_set_pivots")


func _set_pivots() -> void:
	score_label.pivot_offset = score_label.size / 2.0
	train_image.pivot_offset = train_image.size / 2.0

func _process(delta: float) -> void:
	if not is_server_connected: return
	
	time_passed += delta

	# Rhythmic retro style engine vibration
	vibration_timer += delta
	if vibration_timer >= 0.06: # Update roughly 16 times per second for a distinct retro tick
		vibration_timer = 0.0
		current_vibration_offset = randi_range(-1, 1) * 2.0

	if train_image:
		# Since it's centered in a 256x256 box but is 1280x1280, the top-left is at -512, -512
		# Shifted down by 75 pixels (-512.0 + 75.0 = -437.0) to correctly position the train on the tracks
		train_image.position.y = -437.0 + current_vibration_offset

func rebuild_action_buttons(buttons_list: Array) -> void:
	# Clear existing buttons
	for child in action_buttons_container.get_children():
		child.queue_free()
		
	for btn_data in buttons_list:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = btn_data.name + " (+" + str(btn_data.value) + ")"
		
		# Keep pivot offset aligned for click/bounce animations dynamically
		btn.item_rect_changed.connect(func():
			btn.pivot_offset = btn.size / 2.0
		)
		
		var action_id = btn_data.id
		var action_name = btn_data.name
		var points = float(btn_data.value)
		
		btn.pressed.connect(func():
			if tutorial_active:
				_end_tutorial()
				
			_animate_button_press(btn)
			_animate_train_jolt()
			_add_camera_shake(points)
			_spawn_click_burst(btn, action_name)
			_spawn_gold_ticket(btn)
			AudioManager.play_click(points)
			GameManager.add_action(action_id)
		)
		btn.mouse_entered.connect(func():
			AudioManager.play("hover", 0.95, 1.05)
		)
		
		action_buttons_container.add_child(btn)

func _start_tutorial_highlights() -> void:
	tutorial_active = true

func _end_tutorial() -> void:
	tutorial_active = false
	
	GameManager.stats.has_seen_tutorial = true
	GameManager.save_game()
	
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		GameManager.sync_progress_to_server.rpc_id(1, GameManager.stats.total_tickets, GameManager.stats.has_seen_tutorial, GameManager.stats.action_counts)

func _spawn_click_burst(btn: Button, action_name: String) -> void:
	var burst = ClickBurst.instantiate()
	burst.global_position = btn.get_global_mouse_position()
	burst.set_color_for_action(action_name)
	add_child(burst)

func _spawn_gold_ticket(btn: Button) -> void:
	var ticket = GoldTicket.instantiate()
	ticket.global_position = btn.get_global_mouse_position()
	add_child(ticket)
	# Target the ticket bin
	ticket.fly_to_bin(ticket_bin.global_position + Vector2(16, 16))
	
	# Update ticket label when ticket arrives
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		_update_tickets()
	)

func _add_camera_shake(points: int) -> void:
	if camera and camera.has_method("add_trauma"):
		var trauma_amount = 0.2 + (points * 0.1)
		camera.add_trauma(trauma_amount)

func _animate_train_jolt() -> void:
	if not train_image: return
	var tween = create_tween()
	# Tilt back
	tween.tween_property(train_image, "rotation", deg_to_rad(-8), 0.05).set_ease(Tween.EASE_OUT)
	# Snap back
	tween.tween_property(train_image, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _animate_button_press(btn: Button) -> void:
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.9, 0.9), 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN_OUT)

func _update_score(new_distance: float):
	score_label.text = "Distance: " + NumberFormatter.format_value(new_distance, 2) + " km"

func _update_speed(new_speed: float):
	speed_label.text = "Speed: " + NumberFormatter.format_value(new_speed, 1) + " km/h"
	
func _update_tickets():
	ticket_label.text = "x " + NumberFormatter.format_value(GameManager.stats.total_tickets, 0)

func _on_milestone_reached(event_name: String) -> void:
	AudioManager.play("select")
	match event_name:
		"unlock_steam":
			if steam_particles: 
				steam_particles.emitting = true
		"reach_space":
			_transition_to_space()

func _on_milestone_locked(event_name: String) -> void:
	match event_name:
		"unlock_steam":
			if steam_particles:
				steam_particles.emitting = false
		"reach_space":
			_revert_from_space()

func _on_server_disconnected() -> void:
	is_server_connected = false
	var parallax = $ParallaxBackground
	if parallax:
		parallax.set_process(false)
	if steam_particles:
		steam_particles.emitting = false

func _transition_to_space():

	var tween = create_tween()
	# Shake the camera during transition
	_add_camera_shake(5)
	
	# Crossfade background
	tween.tween_property(sky_sprite, "modulate", Color.BLACK, 2.0)
	tween.parallel().tween_property(track_sprite, "modulate", Color(0.5, 0.5, 1.0, 0.0), 1.5)
	
	tween.tween_callback(func():
		sky_sprite.texture = StarfieldTexture
		sky_sprite.modulate = Color.WHITE
		track_sprite.texture = SpaceTrackTexture
		track_sprite.modulate = Color.WHITE
		
		# Change particles to space/plasma look
		if steam_particles:
			steam_particles.color = Color(0.4, 0.7, 1.0, 0.6) # Plasma blue
			steam_particles.gravity = Vector2(0, 0) # No gravity in space
			steam_particles.direction = Vector2(-1, -0.5) # Float away
			steam_particles.initial_velocity_min = 50
			steam_particles.initial_velocity_max = 100
	)

func _revert_from_space():
	var tween = create_tween()
	_add_camera_shake(5)
	
	tween.tween_property(sky_sprite, "modulate", Color.BLACK, 2.0)
	tween.parallel().tween_property(track_sprite, "modulate", Color(0.5, 0.5, 1.0, 0.0), 1.5)
	
	tween.tween_callback(func():
		sky_sprite.texture = CloudsTexture
		sky_sprite.modulate = Color.WHITE
		track_sprite.texture = NormalTrackTexture
		track_sprite.modulate = Color.WHITE
		
		# Revert particles to normal steam
		if steam_particles:
			steam_particles.color = Color(1.0, 1.0, 1.0, 0.6)
			steam_particles.gravity = Vector2(0, -98) # Normal gravity
			steam_particles.direction = Vector2(-1, 0) # Backwards
			steam_particles.initial_velocity_min = 100
			steam_particles.initial_velocity_max = 200
	)

	# Final flash/pop
	tween.tween_property(sky_sprite, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(sky_sprite, "scale", Vector2(1.0, 1.0), 0.5)


func _on_distance_changed(new_distance: float):
	_update_score(new_distance)

func _on_tickets_changed(_new_tickets: float):
	_update_tickets()

func _on_speed_changed(new_speed: float):
	_update_speed(new_speed)
	if new_speed > last_speed:
		var tween = create_tween()
		speed_label.modulate = Color(1.5, 1.5, 0.5) 
		tween.tween_property(speed_label, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(speed_label, "modulate", Color.WHITE, 0.3)
		tween.tween_property(speed_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT)
	last_speed = new_speed

func _on_logs_updated(logs: Array):
	for child in log_vbox.get_children():
		child.queue_free()
		
	for log_msg in logs:
		var lbl = Label.new()
		lbl.text = "> " + log_msg
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		log_vbox.add_child(lbl)
		
	# Scroll to bottom
	call_deferred("_scroll_log_to_bottom")

func _scroll_log_to_bottom():
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

func _on_train_upgraded(level: int):
	var tween = create_tween()
	var base_scale = Vector2(1.0 + (level * 0.1), 1.0 + (level * 0.1))
	tween.tween_property(train_image, "scale", base_scale * 1.5, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(train_image, "scale", base_scale, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)




func _on_leaderboard_pressed() -> void:
	LeaderboardUI.show_leaderboard()

func _on_admin_pressed() -> void:
	var tower_scene = load("res://scenes/admin/control_tower.tscn")
	var tower = tower_scene.instantiate()
	$UILayer.add_child(tower)

func _on_report_bug_pressed() -> void:
	bug_report_modal.open_modal()
