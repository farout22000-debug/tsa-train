extends ColorRect

@onready var close_btn = %BtnClose
@onready var buttons_vbox = %ButtonsVBox
@onready var btn_save_all = %BtnSaveAll

var row_nodes: Array = []

func _ready():
	close_btn.pressed.connect(func(): hide())
	btn_save_all.pressed.connect(_on_save_all_pressed)
	hide()

func open_panel():
	_refresh_list()
	show()

func _refresh_list():
	for child in buttons_vbox.get_children():
		child.queue_free()
	row_nodes.clear()
		
	var current_buttons = GameManager.server_buttons
	if current_buttons.is_empty():
		current_buttons = GameManager.DEFAULT_BUTTONS
		
	for btn_data in current_buttons:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)
		
		var lbl_id = Label.new()
		lbl_id.text = "ID: " + btn_data.id
		lbl_id.custom_minimum_size = Vector2(100, 0)
		lbl_id.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_id.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		
		var edit_name = LineEdit.new()
		edit_name.text = btn_data.name
		edit_name.custom_minimum_size = Vector2(150, 0)
		edit_name.placeholder_text = "Name (e.g. Car)"
		
		var label_val = Label.new()
		label_val.text = "Val:"
		label_val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var spin_val = SpinBox.new()
		spin_val.min_value = 0.0
		spin_val.max_value = 1000.0
		spin_val.step = 0.1
		spin_val.value = float(btn_data.value)
		
		var edit_template = LineEdit.new()
		edit_template.text = btn_data.announcement_template
		edit_template.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_template.placeholder_text = "{player_name} did {button_name}! (+{value} km/h)"
		
		row.add_child(lbl_id)
		row.add_child(edit_name)
		row.add_child(label_val)
		row.add_child(spin_val)
		row.add_child(edit_template)
		
		buttons_vbox.add_child(row)
		
		row_nodes.append({
			"id": btn_data.id,
			"edit_name": edit_name,
			"spin_val": spin_val,
			"edit_template": edit_template
		})

func _on_save_all_pressed():
	var new_buttons_list = []
	for row in row_nodes:
		var btn_data = {
			"id": row.id,
			"name": row.edit_name.text.strip_edges(),
			"value": row.spin_val.value,
			"announcement_template": row.edit_template.text.strip_edges()
		}
		# Basic validation
		if btn_data.name.is_empty(): btn_data.name = row.id.capitalize()
		if btn_data.announcement_template.is_empty(): btn_data.announcement_template = "{player_name} triggered {button_name}! (+{value})"
		
		new_buttons_list.append(btn_data)
		
	GameManager.admin_update_buttons.rpc_id(1, new_buttons_list)
	
	btn_save_all.text = "Saved and Applied!"
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func(): btn_save_all.text = "Save & Apply Changes")
