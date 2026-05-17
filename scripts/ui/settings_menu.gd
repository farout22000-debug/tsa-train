extends ColorRect

@onready var close_btn = %BtnClose
@onready var master_slider = %MasterSlider
@onready var sfx_slider = %SfxSlider
@onready var mute_clicks_chk = %MuteClicksChk

var master_bus_idx: int
var sfx_bus_idx: int

func _ready():
	hide()
	master_bus_idx = AudioServer.get_bus_index("Master")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")
	
	close_btn.pressed.connect(func(): hide())
	
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_clicks_chk.toggled.connect(_on_mute_clicks_toggled)

	_update_ui_from_current()

func open_menu():
	_update_ui_from_current()
	show()

func _update_ui_from_current():
	master_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(master_bus_idx)))
	sfx_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus_idx)))
	mute_clicks_chk.set_pressed_no_signal(AudioManager.mute_clicks)

func _on_master_changed(value: float):
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))

func _on_sfx_changed(value: float):
	AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(value))

func _on_mute_clicks_toggled(toggled_on: bool):
	AudioManager.mute_clicks = toggled_on
