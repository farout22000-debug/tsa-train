class_name Milestone
extends Resource

enum MilestoneType { DISTANCE, SPEED }

@export var type: MilestoneType = MilestoneType.DISTANCE
@export var threshold: int = 0
@export var event_name: String = ""
