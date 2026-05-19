extends ColorRect

@onready var close_btn = %BtnClose
@onready var master_slider = %MasterSlider
@onready var mute_clicks_chk = %MuteClicksChk
@onready var pause_scroll_chk = %PauseScrollChk
@onready var undo_sale_btn = %UndoSaleBtn

var master_bus_idx: int

var undo_dialog: ConfirmationDialog
var undo_vbox: VBoxContainer
var selected_sale_timestamp: float = 0.0
var selected_sale_button: Button = null

func _ready():
	hide()
	master_bus_idx = AudioServer.get_bus_index("Master")
	
	close_btn.pressed.connect(func(): hide())
	undo_sale_btn.pressed.connect(_on_undo_sale_pressed)
	
	master_slider.value_changed.connect(_on_master_changed)
	mute_clicks_chk.toggled.connect(_on_mute_clicks_toggled)
	pause_scroll_chk.toggled.connect(_on_pause_scroll_toggled)

	EventBus.sales_history_received.connect(_on_sales_history_received)
	
	undo_dialog = ConfirmationDialog.new()
	undo_dialog.title = "Select Sale to Undo"
	undo_dialog.confirmed.connect(_on_undo_confirmed)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 300)
	
	undo_vbox = VBoxContainer.new()
	undo_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(undo_vbox)
	
	undo_dialog.add_child(scroll)
	add_child(undo_dialog)

	_update_ui_from_current()

func open_menu():
	_update_ui_from_current()
	show()

func _update_ui_from_current():
	master_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(master_bus_idx)))
	mute_clicks_chk.set_pressed_no_signal(AudioManager.mute_clicks)
	pause_scroll_chk.set_pressed_no_signal(ConfigManager.scroll_paused)

func _on_master_changed(value: float):
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))

func _on_mute_clicks_toggled(toggled_on: bool):
	AudioManager.mute_clicks = toggled_on

func _on_pause_scroll_toggled(toggled_on: bool):
	ConfigManager.scroll_paused = toggled_on
	ConfigManager.save_config()

func _on_undo_sale_pressed():
	undo_sale_btn.disabled = true
	undo_sale_btn.text = "Loading..."
	GameManager.request_sales_history.rpc_id(1)

func _on_sales_history_received(history: Array):
	undo_sale_btn.disabled = false
	undo_sale_btn.text = "Undo Recent Sale"
	
	for child in undo_vbox.get_children():
		child.queue_free()
		
	selected_sale_timestamp = 0.0
	selected_sale_button = null
	
	if history.is_empty():
		var lbl = Label.new()
		lbl.text = "No recent sales found."
		undo_vbox.add_child(lbl)
	else:
		# Show newest first
		for i in range(history.size() - 1, -1, -1):
			var sale = history[i]
			var btn = Button.new()
			var time_dict = Time.get_datetime_dict_from_unix_time(int(sale.timestamp))
			var time_str = "%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
			btn.text = time_str + " - " + sale.action_name + " (+" + str(snapped(sale.speed_increase, 0.1)) + " km/h)"
			btn.pressed.connect(func():
				if selected_sale_button:
					selected_sale_button.add_theme_color_override("font_color", Color.WHITE)
				selected_sale_button = btn
				selected_sale_timestamp = float(sale.timestamp)
				btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2, 1))
			)
			undo_vbox.add_child(btn)
			
	undo_dialog.popup_centered()

func _on_undo_confirmed():
	if selected_sale_timestamp > 0.0:
		GameManager.request_undo_sale.rpc_id(1, selected_sale_timestamp)
