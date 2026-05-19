extends ColorRect

@onready var close_btn = %BtnClose
@onready var users_vbox = %UsersVBox


var ban_dialog: ConfirmationDialog
var ban_target_email: String
var ban_target_team_id: int
var ban_target_name: String

var remove_dialog: ConfirmationDialog
var remove_target_email: String
var remove_sales_checkbox: CheckBox

func _ready():
	close_btn.pressed.connect(func(): hide())
	
	ban_dialog = ConfirmationDialog.new()
	ban_dialog.title = "Confirm Ban"
	ban_dialog.confirmed.connect(_on_ban_confirmed)
	add_child(ban_dialog)
	
	remove_dialog = ConfirmationDialog.new()
	remove_dialog.title = "Confirm Delete User"
	remove_dialog.confirmed.connect(_on_remove_confirmed)
	
	remove_sales_checkbox = CheckBox.new()
	remove_sales_checkbox.text = "Also permanently delete all their tickets/sales records"
	remove_sales_checkbox.button_pressed = false
	remove_dialog.add_child(remove_sales_checkbox)
	add_child(remove_dialog)
	
	EventBus.users_sync_received.connect(_on_users_sync_received)
	EventBus.temp_password_received.connect(_on_temp_password_received)	
	hide()

func _on_temp_password_received(email: String, temp_password: String):
	DisplayServer.clipboard_set(temp_password)
	var accept = AcceptDialog.new()
	accept.title = "Temporary Password Generated"
	
	var vbox = VBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "Password for " + email + " has been reset.\nIt has been copied to your clipboard."
	
	var line_edit = LineEdit.new()
	line_edit.text = temp_password
	line_edit.editable = false
	
	vbox.add_child(lbl)
	vbox.add_child(line_edit)
	accept.add_child(vbox)
	
	add_child(accept)
	accept.popup_centered()
	accept.confirmed.connect(func(): accept.queue_free())

func _on_ban_confirmed():
	if ban_target_email.is_empty(): return
	GameManager.update_user_admin(ban_target_email, ban_target_team_id, ban_target_name, true)
	
	var accept = AcceptDialog.new()
	accept.title = "User Banned"
	accept.dialog_text = "User " + ban_target_email + " has been banned."
	add_child(accept)
	accept.popup_centered()
	accept.confirmed.connect(func(): accept.queue_free())
	
	ban_target_email = ""
	_refresh_list()

func _on_remove_confirmed():
	if remove_target_email.is_empty(): return
	var delete_sales = remove_sales_checkbox.button_pressed
	GameManager.delete_user_admin.rpc_id(1, remove_target_email, delete_sales)
	
	var accept = AcceptDialog.new()
	accept.title = "User Removed"
	accept.dialog_text = "User " + remove_target_email + " has been permanently deleted."
	if delete_sales:
		accept.dialog_text += "\nTheir sales records/save file have also been deleted."
	add_child(accept)
	accept.popup_centered()
	accept.confirmed.connect(func(): accept.queue_free())
	
	remove_target_email = ""

func open_panel():
	size = get_parent().size
	_show_loading()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		GameManager.request_users_list.rpc_id(1)
	else:
		_refresh_list()
	show()

func _show_loading():
	for child in users_vbox.get_children():
		child.queue_free()
	var lbl = Label.new()
	lbl.text = "  Loading users from server..."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	users_vbox.add_child(lbl)

func _on_users_sync_received(_users: Dictionary):
	_refresh_list()

func _refresh_list():
	for child in users_vbox.get_children():
		child.queue_free()
		
	for email in GameManager.server_users:
		var u = GameManager.server_users[email]
		if u.has("is_banned") and u.is_banned:
			continue
			
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		
		var lbl_email = Label.new()
		lbl_email.text = email
		lbl_email.custom_minimum_size = Vector2(250, 0)
		lbl_email.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var edit_name = LineEdit.new()
		edit_name.text = u.name
		edit_name.custom_minimum_size = Vector2(150, 0)
		edit_name.placeholder_text = "Name"
		
		var label_team = Label.new()
		label_team.text = "Team:"
		label_team.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var spin_team = SpinBox.new()
		spin_team.min_value = 1
		spin_team.max_value = 15
		spin_team.value = u.team_id
		
		var btn_save = Button.new()
		btn_save.text = "Save"
		btn_save.pressed.connect(func():
			GameManager.update_user_admin(email, int(spin_team.value), edit_name.text, false)
			btn_save.text = "Saved!"
			var tween = create_tween()
			tween.tween_interval(1.5)
			tween.tween_callback(func(): btn_save.text = "Save")
		)
		
		var btn_reset_pwd = Button.new()
		btn_reset_pwd.text = "Reset Pwd"
		btn_reset_pwd.pressed.connect(func():
			var confirm = ConfirmationDialog.new()
			confirm.title = "Confirm Reset"
			confirm.dialog_text = "Reset password for " + email + "?"
			confirm.confirmed.connect(func():
				GameManager.reset_user_password_admin.rpc_id(1, email)
				confirm.queue_free()
			)
			confirm.canceled.connect(func(): confirm.queue_free())
			add_child(confirm)
			confirm.popup_centered()
		)
		
		var btn_ban = Button.new()
		btn_ban.text = "Ban"
		btn_ban.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		btn_ban.add_theme_color_override("font_hover_color", Color(1, 0.5, 0.5))
		btn_ban.pressed.connect(func():
			ban_target_email = email
			ban_target_team_id = int(spin_team.value)
			ban_target_name = edit_name.text
			ban_dialog.dialog_text = "Are you sure you want to ban " + email + "?"
			ban_dialog.popup_centered()
		)
		
		var btn_remove = Button.new()
		btn_remove.text = "Remove"
		btn_remove.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		btn_remove.add_theme_color_override("font_hover_color", Color(1, 0.4, 0.4))
		btn_remove.pressed.connect(func():
			remove_target_email = email
			remove_dialog.dialog_text = "Are you sure you want to completely delete the user:\n" + email + "?"
			remove_sales_checkbox.button_pressed = false
			remove_dialog.popup_centered()
		)
		
		row.add_child(lbl_email)
		row.add_child(edit_name)
		row.add_child(label_team)
		row.add_child(spin_team)
		row.add_child(btn_save)
		row.add_child(btn_reset_pwd)
		row.add_child(btn_ban)
		row.add_child(btn_remove)
		
		users_vbox.add_child(row)
