extends CanvasLayer

@onready var container = %Container
@onready var label = %Label
@onready var particles = %Particles

var queue: Array[String] = []
var is_animating: bool = false

func _ready():
	EventBus.announcement_requested.connect(_on_announcement_requested)
	container.modulate.a = 0
	container.scale = Vector2.ZERO
	# Make sure it anchors to the top center, we adjust position manually in animation
	container.pivot_offset = container.size / 2.0

func _on_announcement_requested(text: String):
	queue.append(text)
	_process_queue()

func _process_queue():
	if is_animating or queue.is_empty():
		return
		
	is_animating = true
	var text = queue.pop_front()
	label.text = text
	
	# Reset state
	container.pivot_offset = container.size / 2.0
	container.position = Vector2((get_viewport().size.x - container.size.x) / 2.0, 100)
	container.modulate.a = 1.0
	container.scale = Vector2.ZERO
	
	# Start particles
	particles.emitting = true
	
	var tween = create_tween()
	# The "Pop"
	tween.tween_property(container, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Hold
	tween.tween_interval(1.5)
	
	# The "Fade" & "Slide"
	tween.tween_property(container, "position:y", -100.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(container, "modulate:a", 0.0, 0.5)
	
	tween.finished.connect(_on_animation_finished)

func _on_animation_finished():
	particles.emitting = false
	is_animating = false
	_process_queue()
