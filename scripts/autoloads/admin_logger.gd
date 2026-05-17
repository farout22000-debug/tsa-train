extends Node

const LOG_FILE = "user://logs/admin_audit.log"
const MAX_LOG_SIZE = 5 * 1024 * 1024 # 5MB

signal log_updated(message: String)

func _ready():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("logs"):
		dir.make_dir("logs")
		
func log_event(message: String, category: String = "INFO"):
	var datetime = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d %02d:%02d:%02d" % [datetime.year, datetime.month, datetime.day, datetime.hour, datetime.minute, datetime.second]
	var formatted_msg = "[%s] [%s] %s" % [time_str, category, message]
	
	_write_to_file(formatted_msg)
	log_updated.emit(formatted_msg)
	print("[AdminLogger] ", formatted_msg)

func _write_to_file(msg: String):
	_check_log_rotation()
	
	var file = FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
		
	if file:
		file.seek_end()
		file.store_line(msg)
		file.close()

func _check_log_rotation():
	if FileAccess.file_exists(LOG_FILE):
		var file = FileAccess.open(LOG_FILE, FileAccess.READ)
		if file:
			var size = file.get_length()
			file.close()
			if size > MAX_LOG_SIZE:
				var dir = DirAccess.open("user://logs")
				dir.copy(LOG_FILE, LOG_FILE + ".old")
				dir.remove(LOG_FILE)
