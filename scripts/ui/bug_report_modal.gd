extends ColorRect

signal bug_modal_closed

@onready var close_btn = %BtnClose
@onready var submit_btn = %BtnSubmit
@onready var category_option = %CategoryOption
@onready var description_edit = %DescriptionEdit
@onready var char_count_label = %CharCountLabel
@onready var form_vbox = %FormVBox
@onready var success_vbox = %SuccessVBox

const MAX_CHARS = 500

func _ready():
	close_btn.pressed.connect(_close)
	submit_btn.pressed.connect(_on_submit_pressed)
	description_edit.text_changed.connect(_on_text_changed)
	
	EventBus.bug_submit_result.connect(_on_submit_result)
	
	success_vbox.hide()
	form_vbox.show()
	_update_char_count()

func open_modal():
	description_edit.text = ""
	submit_btn.text = "Submit"
	_update_char_count()
	success_vbox.hide()
	form_vbox.show()
	show()

func _close():
	bug_modal_closed.emit()
	hide()

func _on_text_changed():
	var text_length = description_edit.text.length()
	if text_length > MAX_CHARS:
		description_edit.text = description_edit.text.substr(0, MAX_CHARS)
		description_edit.set_caret_column(MAX_CHARS)
		text_length = MAX_CHARS
	_update_char_count(text_length)

func _update_char_count(text_length: int = -1):
	if text_length == -1:
		text_length = description_edit.text.length()
		
	char_count_label.text = str(text_length) + " / " + str(MAX_CHARS)
	
	if text_length == 0:
		submit_btn.disabled = true
		char_count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	elif text_length >= MAX_CHARS:
		submit_btn.disabled = true
		char_count_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif text_length > MAX_CHARS * 0.8:
		submit_btn.disabled = false
		char_count_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	else:
		submit_btn.disabled = false
		char_count_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))

func _on_submit_pressed():
	if description_edit.text.strip_edges().is_empty(): return
	
	submit_btn.disabled = true
	submit_btn.text = "Submitting..."
	
	var category = category_option.get_item_text(category_option.selected)
	var description = description_edit.text
	var os_name = OS.get_name()
	
	GameManager.submit_bug_report.rpc_id(1, category, description, os_name)

func _on_submit_result(success: bool, _message: String):
	if success and visible:
		AudioManager.play("select")
		form_vbox.hide()
		success_vbox.show()
		
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(_close)
	elif not success and visible:
		submit_btn.text = "Error!"
		submit_btn.disabled = false
