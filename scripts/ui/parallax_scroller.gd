extends ParallaxBackground

@export var base_scroll_speed: float = 420.0 # Divisible by 60 for integer pixel steps per frame

func _process(delta: float) -> void:
	scroll_base_offset.x -= base_scroll_speed * delta
	# Wrap at a multiple of 1024 / 0.2 (the motion scale) to prevent floating point drift and jitter
	scroll_base_offset.x = fmod(scroll_base_offset.x, 5120.0)
