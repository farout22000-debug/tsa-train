extends SceneTree

func _init():
	print("--- NumberFormatter Tests ---")
	print("123 (0) -> ", NumberFormatter.format_value(123.0, 0))
	print("123 (2) -> ", NumberFormatter.format_value(123.0, 2))
	print("1500 (2) -> ", NumberFormatter.format_value(1500.0, 2))
	print("1,000,000,000 (2) -> ", NumberFormatter.format_value(1000000000.0, 2))
	print("1.5e15 (2) -> ", NumberFormatter.format_value(1.5e15, 2))
	print("1e30 (2) -> ", NumberFormatter.format_value(1e30, 2))
	print("--- End Tests ---")
	quit()
