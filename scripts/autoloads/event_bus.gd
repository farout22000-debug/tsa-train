extends Node

signal announcement_requested(message: String)
signal auth_result(success: bool, message: String, team_id: int, role: String, player_name: String, tickets: float, has_seen_tutorial: bool, action_counts: Dictionary)

signal bug_submit_result(success: bool, message: String)
signal bugs_sync_received(bugs: Dictionary)
signal users_sync_received(users: Dictionary)
