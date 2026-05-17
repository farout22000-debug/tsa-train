extends Control

@onready var lbl_throughput = %LblThroughput
@onready var lbl_memory = %LblMemory
@onready var lbl_fps = %LblFps
@onready var btn_trillion = %BtnTrillion
@onready var btn_quadrillion = %BtnQuadrillion
@onready var btn_quintillion = %BtnQuintillion
@onready var chk_bot_mode = %ChkBotMode
@onready var btn_close = %BtnClose

var is_bot_mode_active: bool = false
var bot_timer: float = 0.0
var bot_interval: float = 0.1 # 10 clicks per sec per bot

func _ready():
	hide()
	btn_close.pressed.connect(func(): hide())
	
	btn_trillion.pressed.connect(func(): _inject_distance(1e12))
	btn_quadrillion.pressed.connect(func(): _inject_distance(1e15))
	btn_quintillion.pressed.connect(func(): _inject_distance(1e18))
	
	chk_bot_mode.toggled.connect(func(toggled_on): is_bot_mode_active = toggled_on)

func open_panel():
	show()

func _process(delta: float):
	if not visible:
		return
		
	lbl_fps.text = "FPS: " + str(Engine.get_frames_per_second())
	lbl_memory.text = "Memory: " + NumberFormatter.format_value(OS.get_static_memory_usage() / 1024.0 / 1024.0, 1) + " MB"
	lbl_throughput.text = "Server Throughput: " + str(GameManager.clicks_per_second) + " clicks/sec"
	
	if is_bot_mode_active and multiplayer.has_multiplayer_peer():
		bot_timer += delta
		if bot_timer >= bot_interval:
			bot_timer = 0.0
			# Simulate 50 virtual users
			for i in range(50):
				# Directly trigger the action endpoint
				GameManager.add_action("car")

func _inject_distance(val: float):
	GameManager.admin_override_team.rpc_id(1, GameManager.stats.team_id, -1, val)
