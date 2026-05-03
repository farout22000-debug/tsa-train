extends Node

signal distance_changed(new_distance: float)
signal speed_changed(new_speed: float)
signal train_upgraded(level: int)
signal milestone_reached(event_name: String)
signal buff_started(buff_name: String, duration: float)

const SAVE_PATH = "user://savegame.tres"

var stats: PlayerStats
var active_milestone_config: MilestoneList

# Array to hold active buffs (Dictionaries: { "action": String, "multiplier": float, "time_left": float })
var active_buffs: Array[Dictionary] = []

func _ready():
	_init_default_milestones()
	load_game()
	
	# Ensure signals fire initially
	call_deferred("emit_signal", "speed_changed", stats.current_speed)
	call_deferred("emit_signal", "distance_changed", stats.total_distance)

func _process(delta: float):
	if not stats: return
	
	# Process active buffs
	for i in range(active_buffs.size() - 1, -1, -1):
		active_buffs[i].time_left -= delta
		if active_buffs[i].time_left <= 0:
			active_buffs.remove_at(i)
	
	# Calculate distance
	# Speed is in km/h. To get km/sec, divide by 3600.
	var distance_delta = (stats.current_speed / 3600.0) * delta
	stats.total_distance += distance_delta
	
	# Emit distance changed (UI can decide how often to update, or we update every frame)
	distance_changed.emit(stats.total_distance)
	
	_check_milestones()
	_check_upgrades()

func _init_default_milestones() -> void:
	active_milestone_config = MilestoneList.new()
	var m1 = Milestone.new()
	m1.threshold = 50 # Now checking total_distance or tickets? Let's check distance.
	m1.event_name = "unlock_steam"
	active_milestone_config.milestones.append(m1)

func load_game() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		stats = ResourceLoader.load(SAVE_PATH) as PlayerStats
	if not stats:
		stats = PlayerStats.new()

func save_game() -> void:
	if stats:
		ResourceSaver.save(stats, SAVE_PATH)

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

func get_multiplier(action_name: String) -> float:
	var multiplier = 1.0
	for buff in active_buffs:
		if buff.action == action_name or buff.action == "ALL":
			multiplier *= buff.multiplier
	return multiplier

func add_buff(action_name: String, multiplier: float, duration: float) -> void:
	active_buffs.append({
		"action": action_name,
		"multiplier": multiplier,
		"time_left": duration
	})
	buff_started.emit(action_name + " " + str(multiplier) + "x", duration)

func add_action(action_name: String, base_speed_increase: float) -> void:
	# Calculate actual speed increase with multipliers
	var actual_increase = base_speed_increase * get_multiplier(action_name)
	
	stats.add_action(action_name)
	stats.current_speed += actual_increase
	
	speed_changed.emit(stats.current_speed)
	EventBus.announcement_requested.emit(stats.player_name + " pressed " + action_name + "! Speed +" + str(snapped(actual_increase, 0.1)) + " km/h")
	
	# Example VIP Boarding Check (RSA adds a global multiplier to CTP for 2 minutes)
	if action_name == "RSA":
		add_buff("CTP", 2.0, 120.0) # 2x CTP value for 120 seconds
		EventBus.announcement_requested.emit("VIP Boarded! CTP speed boost doubled for 2 minutes!")

	save_game()

func _check_milestones() -> void:
	if not active_milestone_config: return
	for m in active_milestone_config.milestones:
		# Using total_distance for milestones now
		if stats.total_distance >= m.threshold and not stats.has_unlocked(m.event_name):
			stats.unlock_event(m.event_name)
			milestone_reached.emit(m.event_name)

func _check_upgrades() -> void:
	# Upgrades could be tied to distance or tickets. Let's use distance for now.
	pass
