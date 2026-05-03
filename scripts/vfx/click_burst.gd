extends CPUParticles2D

func _ready():
	emitting = true
	var timer = get_tree().create_timer(lifetime + 0.1)
	timer.timeout.connect(queue_free)

func set_color_for_action(action_name: String):
	match action_name:
		"RSA":
			color = Color(1.0, 0.8, 0.2) # Gold
		"CTP":
			color = Color(0.8, 0.2, 1.0) # Purple
		"Home":
			color = Color(0.2, 0.8, 0.2) # Green
		"Car":
			color = Color(0.2, 0.5, 1.0) # Blue
		"Renewal":
			color = Color(1.0, 1.0, 1.0) # White
		_:
			color = Color(1.0, 1.0, 1.0)
