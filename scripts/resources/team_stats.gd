extends Resource
class_name TeamStats

@export var team_id: int = 0
@export var total_distance: float = 0.0
@export var current_speed: float = 20.0
@export var total_tickets: float = 0.0
@export var unlocked_events: Array[String] = []
@export var members: Array[String] = []

func add_member(email: String):
	if not email in members:
		members.append(email)

func has_members() -> bool:
	return not members.is_empty()
