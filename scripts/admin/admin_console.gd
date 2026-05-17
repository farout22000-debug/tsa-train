extends CanvasLayer

@onready var log_label = %LogLabel
@onready var input_field = %InputField
@onready var btn_close = %BtnClose

func _ready():
	visible = false
	btn_close.pressed.connect(hide_console)
	input_field.text_submitted.connect(_on_command_submitted)
	AdminLogger.log_updated.connect(_on_log_updated)
	
func show_console():
	visible = true
	input_field.grab_focus()

func hide_console():
	visible = false

func _on_log_updated(msg: String):
	if log_label:
		log_label.text += msg + "\n"

func _on_command_submitted(text: String):
	input_field.text = ""
	_parse_command(text.strip_edges())

func _parse_command(cmd: String):
	if cmd.is_empty(): return
	
	AdminLogger.log_event("User executed: " + cmd, "CMD")
	
	var parts = cmd.split(" ", false)
	var action = parts[0].to_lower()
	
	match action:
		"/speed":
			if parts.size() > 1:
				GameManager.admin_set_speed(parts[1].to_float())
			else:
				AdminLogger.log_event("Usage: /speed [value]", "ERROR")
		"/tickets":
			if parts.size() > 1:
				GameManager.admin_give_tickets(parts[1].to_float())
			else:
				AdminLogger.log_event("Usage: /tickets [value]", "ERROR")
		"/msg":
			if parts.size() > 1:
				var msg = cmd.substr(parts[0].length()).strip_edges()
				GameManager.admin_send_message(msg)
			else:
				AdminLogger.log_event("Usage: /msg [text]", "ERROR")
		"/clear":
			log_label.text = ""
		"/help":
			var help_msg = "Available Commands:\n"
			help_msg += "/speed [value] - Set global train speed\n"
			help_msg += "/tickets [value] - Grant/Remove tickets to all players\n"
			help_msg += "/msg [text] - Send a global server announcement\n"
			help_msg += "/clear - Clear the console log view\n"
			help_msg += "/help - Show this help message"
			AdminLogger.log_updated.emit(help_msg)
		_:
			AdminLogger.log_event("Unknown command: " + action, "ERROR")
