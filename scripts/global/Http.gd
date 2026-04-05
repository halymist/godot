extends Node

# ============================================
# HTTP AUTOLOAD
# ============================================
# Handles all HTTP communication with the server
# Authentication, character management, and account operations

# Base URL for the server API
var base_url = "http://localhost:8080"

# Signals for async responses
signal login_completed(success: bool, data: Dictionary, error: String)
signal create_character_completed(success: bool, character_id: int, error: String)

# Session ID from successful login (used for authenticated requests)
var session_id: String = ""

func _ready():
	print("Http ready!")

# ============================================
# HTTP API - Helper Functions
# ============================================

func _create_http_request() -> HTTPRequest:
	"""Create a new HTTPRequest node for a single request"""
	var http_request = HTTPRequest.new()
	add_child(http_request)
	return http_request

func _get_headers(include_session: bool = false) -> PackedStringArray:
	"""Get common headers for requests"""
	var headers = PackedStringArray([
		"Content-Type: application/json"
	])
	if include_session and session_id != "":
		headers.append("Authorization: Bearer " + session_id)
	return headers

# ============================================
# Authentication Actions
# ============================================

func login(email: String, password: String):
	"""
	Login to account with email and password
	
	Emits login_completed signal with:
	- success: bool - whether login was successful
	- data: Dictionary - lobby data on success (account info, server list)
	- error: String - error message on failure
	"""
	var http_request = _create_http_request()
	http_request.request_completed.connect(_on_login_completed.bind(http_request))
	
	var payload = {
		"email": email,
		"password": password
	}
	
	var json_payload = JSON.stringify(payload)
	var url = base_url + "/login"
	
	print("[HTTP] POST ", url)
	var error = http_request.request(url, _get_headers(), HTTPClient.METHOD_POST, json_payload)
	
	if error != OK:
		print("[HTTP] Failed to send login request: ", error)
		http_request.queue_free()
		login_completed.emit(false, {}, "Failed to send request")

func _on_login_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle login response from server"""
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[HTTP] Login request failed with result: ", result)
		login_completed.emit(false, {}, "Connection failed")
		return
	
	var body_text = body.get_string_from_utf8()
	print("[HTTP] Login response (", response_code, "): ", body_text)
	
	if response_code != 200:
		var error_msg = "Login failed (HTTP " + str(response_code) + ")"
		# Try to parse error message from response
		var err_json = JSON.new()
		if err_json.parse(body_text) == OK:
			var err_response = err_json.get_data()
			if err_response is Dictionary and err_response.has("error"):
				error_msg = err_response["error"]
		login_completed.emit(false, {}, error_msg)
		return
	
	# Parse successful response
	var json = JSON.new()
	if json.parse(body_text) != OK:
		print("[HTTP] Failed to parse login response")
		login_completed.emit(false, {}, "Invalid server response")
		return
	
	var response = json.get_data()
	if not response is Dictionary:
		login_completed.emit(false, {}, "Invalid server response format")
		return
	
	# Store session ID
	if response.has("session_id"):
		session_id = response["session_id"]
	
	# If response already includes lobby data, emit immediately
	var has_lobby_data = response.has("server_list") or response.has("data_versions") or response.has("mushrooms") or response.has("user_email") or response.has("account_created")
	if has_lobby_data:
		var lobby_data = _transform_auth_response(response)
		login_completed.emit(true, lobby_data, "")
		return
	
	# Otherwise, fetch lobby data before emitting
	fetch_lobby()

func _transform_auth_response(response: Dictionary) -> Dictionary:
	"""Transform server AuthResponse to client lobby_data format"""
	var uid = response.get("user_id", 0)
	GameInfo.user_id = str(int(uid)) if uid else ""
	var lobby_data = {
		"user_id": uid,
		"account_created": response.get("account_created", ""),
		"user_email": response.get("user_email", ""),
		"email": response.get("user_email", ""),
		"mushrooms": response.get("mushrooms", 0),
		"connected_methods": response.get("user_connected_methods", []),
		"new_server_timestamp": response.get("new_server_timestamp", null),
		"server_list": response.get("server_list", []),
		"data_versions": response.get("data_versions", {})
	}
	
	return lobby_data

func fetch_lobby():
	"""Fetch lobby data using stored session ID and emit login_completed when ready."""
	if session_id.is_empty():
		login_completed.emit(false, {}, "Missing session ID for lobby request")
		return

	var http_request = _create_http_request()
	http_request.request_completed.connect(_on_lobby_completed.bind(http_request))
	var url = base_url + "/lobby"
	print("[HTTP] GET ", url)
	var error = http_request.request(url, _get_headers(true), HTTPClient.METHOD_GET, "")
	if error != OK:
		print("[HTTP] Failed to send lobby request: ", error)
		http_request.queue_free()
		login_completed.emit(false, {}, "Failed to request lobby data")

func _on_lobby_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle lobby response from server"""
	http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[HTTP] Lobby request failed with result: ", result)
		login_completed.emit(false, {}, "Connection failed")
		return

	var body_text = body.get_string_from_utf8()
	print("[HTTP] Lobby response (", response_code, "): ", body_text)
	if response_code != 200:
		login_completed.emit(false, {}, "Lobby load failed (HTTP " + str(response_code) + ")")
		return

	var json = JSON.new()
	if json.parse(body_text) != OK:
		print("[HTTP] Failed to parse lobby response")
		login_completed.emit(false, {}, "Invalid lobby response")
		return

	var response = json.get_data()
	if not response is Dictionary:
		login_completed.emit(false, {}, "Invalid lobby response format")
		return

	var lobby_data = _transform_auth_response(response)
	login_completed.emit(true, lobby_data, "")

func register(auth_type: String, _username: String = "", _password: String = ""):
	"""
	Register new account (placeholder - will be implemented later)
	auth_type: Authentication method (e.g., "google", "mail", "facebook")
	_username: Optional - username/email for certain auth types
	_password: Optional - password for certain auth types
	
	Response: success/failure message
	"""
	# TODO: Implement actual register endpoint
	print("[HTTP] Register not yet implemented - auth_type: ", auth_type)

func logout():
	"""
	Logout from current account - sends logout request to server
	
	Response: success confirmation
	"""
	if session_id.is_empty():
		print("[HTTP] No session to logout")
		return
	
	var http_request = _create_http_request()
	http_request.request_completed.connect(_on_logout_completed.bind(http_request))
	
	var url = base_url + "/logout"
	
	print("[HTTP] POST ", url)
	var error = http_request.request(url, _get_headers(true), HTTPClient.METHOD_POST, "")
	
	if error != OK:
		print("[HTTP] Failed to send logout request: ", error)
		http_request.queue_free()
		session_id = ""

func _on_logout_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle logout response from server"""
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[HTTP] Logout request failed with result: ", result)
	else:
		var body_text = body.get_string_from_utf8()
		print("[HTTP] Logout response (", response_code, "): ", body_text)
	
	# Clear session regardless of response
	session_id = ""
	print("[HTTP] Session cleared")

func reset_password(email: String):
	"""
	Send password reset email to the provided email address (placeholder)
	email: Email address to send password reset link to
	
	Response: success/failure confirmation
	"""
	# TODO: Implement actual password reset endpoint
	print("[HTTP] Password reset requested for: ", email)

# ============================================
# Generic Request (for not-yet-implemented endpoints)
# ============================================

func send_request(endpoint: String, method: String, payload: Dictionary):
	"""Send an HTTP request to the server (placeholder for unimplemented endpoints)"""
	print("[HTTP] ", method, " ", endpoint, " | Payload: ", payload)
	# TODO: Implement actual HTTP request when endpoint is ready

# ============================================
# Character Management Actions
# ============================================

func create_character(character_name: String, faction: int, avatar: Array, vip: bool = false):
	"""
	Create a new character on the selected server
	character_name: Character name
	faction: Faction/guild ID
	avatar: Array of avatar customization IDs [face, hair, eyes, nose, mouth]
	vip: VIP status (optional, default false)
	
	Emits create_character_completed signal with:
	- success: bool - whether creation was successful
	- character_id: int - the new character's ID on success
	- error: String - error message on failure
	"""
	var http_request = _create_http_request()
	http_request.request_completed.connect(_on_create_character_completed.bind(http_request))
	
	var payload = {
		"name": character_name,
		"faction": faction,
		"avatar": avatar,
		"vip": vip
	}
	
	var json_payload = JSON.stringify(payload)
	var url = base_url + "/create-character"
	
	print("[HTTP] POST ", url)
	var error = http_request.request(url, _get_headers(true), HTTPClient.METHOD_POST, json_payload)
	
	if error != OK:
		print("[HTTP] Failed to send create character request: ", error)
		http_request.queue_free()
		create_character_completed.emit(false, 0, "Failed to send request")

func _on_create_character_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle create character response from server"""
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[HTTP] Create character request failed with result: ", result)
		create_character_completed.emit(false, 0, "Connection failed")
		return
	
	var body_text = body.get_string_from_utf8()
	print("[HTTP] Create character response (", response_code, "): ", body_text)
	
	if response_code != 200:
		var error_msg = "Character creation failed (HTTP " + str(response_code) + ")"
		# Try to parse error message from response
		var err_json = JSON.new()
		if err_json.parse(body_text) == OK:
			var err_response = err_json.get_data()
			if err_response is Dictionary and err_response.has("error"):
				error_msg = err_response["error"]
		create_character_completed.emit(false, 0, error_msg)
		return
	
	# Parse successful response
	var json = JSON.new()
	if json.parse(body_text) != OK:
		print("[HTTP] Failed to parse create character response")
		create_character_completed.emit(false, 0, "Invalid server response")
		return
	
	var response = json.get_data()
	if not response is Dictionary or not response.has("character_id"):
		create_character_completed.emit(false, 0, "Invalid server response format")
		return
	
	var character_id = response["character_id"]
	create_character_completed.emit(true, character_id, "")

func delete_character(character_id: int):
	"""
	Delete a character
	character_id: ID of the character to delete
	
	Response: success/failure confirmation
	"""
	var payload = {
		"character_id": character_id
	}
	
	send_request("/character/delete", "POST", payload)
