extends ColorRect

@onready var close_btn = %BtnClose
@onready var bugs_vbox = %BugsVBox

func _ready():
	close_btn.pressed.connect(func(): hide())
	EventBus.bugs_sync_received.connect(_on_bugs_received)
	hide()

func open_panel():
	for child in bugs_vbox.get_children():
		child.queue_free()
	
	GameManager.request_bugs_list.rpc_id(1)
	show()

func _on_bugs_received(bugs: Dictionary):
	for child in bugs_vbox.get_children():
		child.queue_free()
		
	var sorted_bugs = bugs.values()
	sorted_bugs.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	for b in sorted_bugs:
		var row = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 15)
		margin.add_theme_constant_override("margin_right", 15)
		margin.add_theme_constant_override("margin_top", 15)
		margin.add_theme_constant_override("margin_bottom", 15)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		
		var header_hbox = HBoxContainer.new()
		var meta_lbl = Label.new()
		var date = Time.get_datetime_string_from_unix_time(b.timestamp).replace("T", " ")
		meta_lbl.text = "[%s] %s | Team: %d | OS: %s" % [date, b.email, b.team_id, b.os]
		meta_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_hbox.add_child(meta_lbl)
		
		var cat_lbl = Label.new()
		cat_lbl.text = "Category: " + b.category
		cat_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.9))
		header_hbox.add_child(cat_lbl)
		
		vbox.add_child(header_hbox)
		
		var desc_lbl = Label.new()
		desc_lbl.text = b.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(0, 40)
		vbox.add_child(desc_lbl)
		
		var actions_hbox = HBoxContainer.new()
		
		var status_lbl = Label.new()
		status_lbl.text = "Status:"
		actions_hbox.add_child(status_lbl)
		
		var status_opt = OptionButton.new()
		status_opt.add_item("Open", 0)
		status_opt.add_item("In Progress", 1)
		status_opt.add_item("Resolved", 2)
		status_opt.add_item("Closed", 3)
		
		var status_map = ["Open", "In Progress", "Resolved", "Closed"]
		status_opt.selected = status_map.find(b.status)
		if status_opt.selected == -1: status_opt.selected = 0
		
		actions_hbox.add_child(status_opt)
		
		var save_btn = Button.new()
		save_btn.text = "Update Status"
		save_btn.pressed.connect(func():
			GameManager.admin_update_bug_status.rpc_id(1, b.id, status_opt.get_item_text(status_opt.selected))
			var tween = create_tween()
			save_btn.text = "Updated!"
			tween.tween_interval(1.5)
			tween.tween_callback(func(): save_btn.text = "Update Status")
		)
		actions_hbox.add_child(save_btn)
		
		var del_btn = Button.new()
		del_btn.text = "Delete"
		del_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		del_btn.pressed.connect(func():
			var dialog = ConfirmationDialog.new()
			dialog.dialog_text = "Are you sure you want to delete this bug?"
			dialog.confirmed.connect(func():
				GameManager.admin_delete_bug.rpc_id(1, b.id)
			)
			add_child(dialog)
			dialog.popup_centered()
		)
		actions_hbox.add_child(del_btn)
		
		vbox.add_child(actions_hbox)
		margin.add_child(vbox)
		row.add_child(margin)
		
		bugs_vbox.add_child(row)
