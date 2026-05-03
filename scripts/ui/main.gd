extends Node2D

@onready var player_name_label = %PlayerNameLabel
@onready var score_label = %ScoreLabel
@onready var speed_label = %SpeedLabel
@onready var ticket_bin = %TicketBin
@onready var ticket_label = %TicketLabel
@onready var train_image = %TrainImage
@onready var steam_particles = %SteamParticles
@onready var camera = $Camera2D

const ClickBurst = preload("res://scenes/vfx/click_burst.tscn")
const GoldTicket = preload("res://scenes/vfx/gold_ticket.tscn")

@onready var btn_car = %BtnCar
@onready var btn_home = %BtnHome
@onready var btn_ctp = %BtnCtp
@onready var btn_rsa = %BtnRsa
@onready var btn_renewal = %BtnRenewal
@onready var btn_mute = %BtnMute
@onready var btn_fullscreen = %BtnFullscreen

var time_passed: float = 0.0

func _ready():
	player_name_label.text = GameManager.get_player_name()
	_update_score(GameManager.get_distance())
	_update_speed(GameManager.get_speed())
	_update_tickets()
	
	GameManager.distance_changed.connect(_on_distance_changed)
	GameManager.speed_changed.connect(_on_speed_changed)
	GameManager.train_upgraded.connect(_on_train_upgraded)
	GameManager.milestone_reached.connect(_on_milestone_reached)
	
	_setup_button(btn_car, "Car", 1)
	_setup_button(btn_home, "Home", 2)
	_setup_button(btn_ctp, "CTP", 3)
	_setup_button(btn_rsa, "RSA", 4)
	_setup_button(btn_renewal, "Renewal", 1)
	
	btn_mute.pressed.connect(_on_mute_pressed)
	btn_fullscreen.pressed.connect(_on_fullscreen_pressed)
	
	# Only show fullscreen button on web builds if desired, or just keep it
	if OS.has_feature("web"):
		btn_fullscreen.show()
	
	# Restore unlocked visual states
	for event in GameManager.stats.unlocked_events:
		_on_milestone_reached(event)
	
	# Delay pivot setting to ensure layout is calculated
	call_deferred("_set_pivots")

func _set_pivots() -> void:
	for btn in [btn_car, btn_home, btn_ctp, btn_rsa, btn_renewal]:
		btn.pivot_offset = btn.size / 2.0
	score_label.pivot_offset = score_label.size / 2.0
	train_image.pivot_offset = train_image.size / 2.0

func _process(delta: float) -> void:
	time_passed += delta
	# Train bobbing effect (using custom_minimum_size to respect layout centering)
	if train_image:
		train_image.custom_minimum_size.y = 256.0 + (sin(time_passed * 4.0) * 10.0)

func _setup_button(btn: Button, action_name: String, points: int) -> void:
	btn.pressed.connect(func():
		_animate_button_press(btn)
		_animate_train_jolt()
		_add_camera_shake(points)
		_spawn_click_burst(btn, action_name)
		_spawn_gold_ticket(btn)
		AudioManager.play_click(points)
		GameManager.add_action(action_name, points)
	)
	btn.mouse_entered.connect(func():
		AudioManager.play("hover", 0.95, 1.05)
	)

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
	score_label.text = "Distance: " + str(snapped(new_distance, 0.01)) + " km"

func _update_speed(new_speed: float):
	speed_label.text = "Speed: " + str(snapped(new_speed, 0.1)) + " km/h"
	
func _update_tickets():
	ticket_label.text = "x " + str(GameManager.stats.total_tickets)

func _on_milestone_reached(event_name: String) -> void:
	AudioManager.play("select")
	match event_name:
		"unlock_steam":
			if steam_particles: 
				steam_particles.emitting = true

func _on_distance_changed(new_distance: float):
	_update_score(new_distance)

func _on_speed_changed(new_speed: float):
	_update_speed(new_speed)
	var tween = create_tween()
	speed_label.modulate = Color(1.5, 1.5, 0.5) 
	tween.tween_property(speed_label, "scale", Vector2(1.2, 1.2), 0.1).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(speed_label, "modulate", Color.WHITE, 0.3)
	tween.tween_property(speed_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT)

func _on_train_upgraded(level: int):
	var tween = create_tween()
	var base_scale = Vector2(1.0 + (level * 0.1), 1.0 + (level * 0.1))
	tween.tween_property(train_image, "scale", base_scale * 1.5, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(train_image, "scale", base_scale, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _on_mute_pressed() -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	var is_muted = AudioServer.is_bus_mute(bus_idx)
	AudioServer.set_bus_mute(bus_idx, not is_muted)
	btn_mute.text = "Unmute" if not is_muted else "Mute"

func _on_fullscreen_pressed() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		btn_fullscreen.text = "Fullscreen"
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		btn_fullscreen.text = "Windowed"
