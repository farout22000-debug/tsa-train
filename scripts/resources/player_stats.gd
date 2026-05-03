class_name PlayerStats
extends Resource

@export var player_name: String = ""
@export var total_distance: float = 0.0
@export var current_speed: float = 20.0 # Base cruising speed
@export var total_tickets: int = 0
@export var train_level: int = 1
@export var action_counts: Dictionary = {
	"Car": 0,
	"Home": 0,
	"CTP": 0,
	"RSA": 0,
	"Renewal": 0
}
@export var unlocked_events: Array[String] = []

func has_unlocked(event_name: String) -> bool:
	return unlocked_events.has(event_name)

func unlock_event(event_name: String) -> void:
	if not unlocked_events.has(event_name):
		unlocked_events.append(event_name)

func add_action(action_name: String) -> void:
	total_tickets += 1
	if action_counts.has(action_name):
		action_counts[action_name] += 1
	else:
		action_counts[action_name] = 1
