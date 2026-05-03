extends Sprite2D

var target_position: Vector2
var duration: float = 1.0

func fly_to_bin(target: Vector2) -> void:
	target_position = target
	
	var tween = create_tween()
	
	# Initial pop up
	var control_point = global_position + Vector2(0, -100)
	
	# Spin
	tween.parallel().tween_property(self, "rotation", deg_to_rad(360 * 2), duration).set_ease(Tween.EASE_OUT)
	
	# Arc movement
	# Since it's a simple arc, we can use a parallel tween for x and an eased tween for y
	tween.parallel().tween_property(self, "global_position:x", target_position.x, duration).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "global_position:y", target_position.y, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	# Scale
	tween.parallel().tween_property(self, "scale", Vector2(0.125, 0.125), duration).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func():
		AudioManager.play("click_light") # "Clink" sound
		queue_free()
	)
