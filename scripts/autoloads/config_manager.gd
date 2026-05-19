extends Node

const CONFIG_FILE = "user://settings.cfg"

var current_ip: String = "127.0.0.1"
var current_port: int = 8090

# Phase 11 & Phase 20: Permanent Static Tunnel URL
# Update this with your Cloudflare domain or Ngrok URL
const PERMANENT_TUNNEL_URL = "wss://disallow-maximize-finless.ngrok-free.dev"

# Phase 12: Email Verification
const EMAIL_API_KEY = "YOUR_BREVO_API_KEY" # Replace with actual API key
const EMAIL_SENDER_EMAIL = "no-reply@tsatrain.com"
const EMAIL_SENDER_NAME = "TSA Train Administration"

# 2FA Settings
var require_2fa: bool = false # Default to false for stealth disable
var scroll_paused: bool = false

func _ready():
	# Command line override
	if "--require-2fa" in OS.get_cmdline_args():
		require_2fa = true
	elif "--no-2fa" in OS.get_cmdline_args():
		require_2fa = false
		
	load_config()

func load_config():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILE)
	if err == OK:
		current_ip = config.get_value("Network", "ip_address", "127.0.0.1")
		current_port = config.get_value("Network", "port", 8090)
		require_2fa = config.get_value("Security", "require_2fa", require_2fa)
		scroll_paused = config.get_value("Display", "scroll_paused", false)
	else:
		save_config() # Create default file

func save_config():
	var config = ConfigFile.new()
	config.set_value("Network", "ip_address", current_ip)
	config.set_value("Network", "port", current_port)
	config.set_value("Security", "require_2fa", require_2fa)
	config.set_value("Display", "scroll_paused", scroll_paused)
	config.save(CONFIG_FILE)

func set_network_settings(ip: String, port: int):
	current_ip = ip
	current_port = port
	save_config()
