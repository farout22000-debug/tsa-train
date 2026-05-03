extends CanvasLayer

@onready var color_rect = $ColorRect

func _ready():
	color_rect.modulate.a = 0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene_to_file(path: String) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	
	get_tree().change_scene_to_file(path)
	
	tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
