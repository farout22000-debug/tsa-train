extends Node

# Brevo (Sendinblue) API endpoint
const API_URL = "https://api.brevo.com/v3/smtp/email"

var http_request: HTTPRequest

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func send_verification_email(to_email: String, code: String) -> void:
	if ConfigManager.EMAIL_API_KEY == "YOUR_BREVO_API_KEY":
		print("[EmailManager] Mock sending verification code %s to %s" % [code, to_email])
		return
		
	var headers = [
		"accept: application/json",
		"api-key: " + ConfigManager.EMAIL_API_KEY,
		"content-type: application/json"
	]
	
	var payload = {
		"sender": {
			"name": ConfigManager.EMAIL_SENDER_NAME,
			"email": ConfigManager.EMAIL_SENDER_EMAIL
		},
		"to": [
			{
				"email": to_email
			}
		],
		"subject": "TSA Train - Registration Verification Code",
		"htmlContent": "<html><body><h2>Welcome to TSA Train!</h2><p>Your verification code is: <strong>%s</strong></p><p>This code will expire in 5 minutes.</p></body></html>" % code,
		"textContent": "Welcome to TSA Train! Your verification code is: %s. This code will expire in 5 minutes." % code
	}
	
	var json_payload = JSON.stringify(payload)
	var error = http_request.request(API_URL, headers, HTTPClient.METHOD_POST, json_payload)
	
	if error != OK:
		print("[EmailManager] Failed to send request: %s" % error)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code >= 200 and response_code < 300:
		print("[EmailManager] Email sent successfully.")
	else:
		var body_str = body.get_string_from_utf8()
		print("[EmailManager] Failed to send email. Code: %d, Response: %s" % [response_code, body_str])
