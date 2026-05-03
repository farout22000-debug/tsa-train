extends Camera2D

@export var max_offset: Vector2 = Vector2(15, 15)
@export var max_roll: float = 0.05
@export var trauma_reduction_rate: float = 1.5

var trauma: float = 0.0
var trauma_power: int = 2

func _ready() -> void:
	randomize()

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if trauma > 0:
		trauma = clamp(trauma - (trauma_reduction_rate * delta), 0.0, 1.0)
		_shake()
	elif offset != Vector2.ZERO or rotation != 0.0:
		offset = Vector2.ZERO
		rotation = 0.0

func _shake() -> void:
	var amount = pow(trauma, trauma_power)
	offset.x = max_offset.x * amount * randf_range(-1.0, 1.0)
	offset.y = max_offset.y * amount * randf_range(-1.0, 1.0)
	rotation = max_roll * amount * randf_range(-1.0, 1.0)
