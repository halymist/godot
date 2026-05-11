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
signal redeem_coupon_completed(success: bool, mushrooms: int, status: String, error: String)

# Session ID from successful login (used for authenticated requests)
var session_id: String = ""
# Last successful create-character raw response payload.
var last_create_character_response: Dictionary = {}

func _ready():
	pass

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
	
	var error = http_request.request(url, _get_headers(), HTTPClient.METHOD_POST, json_payload)
	
	if error != OK:
		http_request.queue_free()
		login_completed.emit(false, {}, "Failed to send request")

func _on_login_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle login response from server"""
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		login_completed.emit(false, {}, "Connection failed")
		return
	
	var body_text = body.get_string_from_utf8()
	
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
	GameInfo.last_auth_response = response.duplicate(true)
	var connected_methods = response.get("user_connected_methods", [])
	var lobby_data = {
		"user_id": uid,
		"account_created": response.get("account_created", ""),
		"user_email": response.get("user_email", ""),
		"email": response.get("user_email", ""),
		"mushrooms": response.get("mushrooms", 0),
		"connected_methods": connected_methods,
		"user_connected_methods": connected_methods,
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
	var error = http_request.request(url, _get_headers(true), HTTPClient.METHOD_GET, "")
	if error != OK:
		http_request.queue_free()
		login_completed.emit(false, {}, "Failed to request lobby data")

func _on_lobby_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle lobby response from server"""
	http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		login_completed.emit(false, {}, "Connection failed")
		return

	var body_text = body.get_string_from_utf8()
	if response_code != 200:
		login_completed.emit(false, {}, "Lobby load failed (HTTP " + str(response_code) + ")")
		return

	var json = JSON.new()
	if json.parse(body_text) != OK:
		login_completed.emit(false, {}, "Invalid lobby response")
		return

	var response = json.get_data()
	if not response is Dictionary:
		login_completed.emit(false, {}, "Invalid lobby response format")
		return

	var lobby_data = _transform_auth_response(response)
	login_completed.emit(true, lobby_data, "")

func register(_auth_type: String, _username: String = "", _password: String = ""):
	"""
	Register new account (placeholder - will be implemented later)
	auth_type: Authentication method (e.g., "google", "mail", "facebook")
	_username: Optional - username/email for certain auth types
	_password: Optional - password for certain auth types
	
	Response: success/failure message
	"""
	# TODO: Implement actual register endpoint

func logout():
	"""
	Logout from current account - sends logout request to server
	
	Response: success confirmation
	"""
	if session_id.is_empty():
		return
	
	var http_request = _create_http_request()
	http_request.request_completed.connect(_on_logout_completed.bind(http_request))
	
	var url = base_url + "/logout"
	
	var error = http_request.request(url, _get_headers(true), HTTPClient.METHOD_POST, "")
	
	if error != OK:
		http_request.queue_free()
		session_id = ""

func _on_logout_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle logout response from server"""
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		pass
	else:
		var _body_text = body.get_string_from_utf8()
	
	# Clear session regardless of response
	session_id = ""

func reset_password(_email: String):
	"""
	Send password reset email to the provided email address (placeholder)
	email: Email address to send password reset link to
	
	Response: success/failure confirmation
	"""
	# TODO: Implement actual password reset endpoint

# ============================================
# Generic Request (for not-yet-implemented endpoints)
# ============================================

func send_request(_endpoint: String, _method: String, _payload: Dictionary):
	"""Send an HTTP request to the server (placeholder for unimplemented endpoints)"""
	# TODO: Implement actual HTTP request when endpoint is ready

# ============================================
# Coupon Actions
# ============================================

func redeem_coupon(coupon_code: String):
	"""Redeem a coupon code for account rewards."""
	if session_id.is_empty():
		redeem_coupon_completed.emit(false, 0, "", "Not authenticated")
		return

	var cleaned_code = coupon_code.strip_edges()
	if cleaned_code.is_empty():
		redeem_coupon_completed.emit(false, 0, "invalid", "Coupon code is empty")
		return

	var http_request = _create_http_request()
	http_request.request_completed.connect(_on_redeem_coupon_completed.bind(http_request))

	var payload = {
		"coupon": cleaned_code
	}
	var json_payload = JSON.stringify(payload)
	var url = base_url + "/redeem-coupon"

	var error = http_request.request(url, _get_headers(true), HTTPClient.METHOD_POST, json_payload)
	if error != OK:
		http_request.queue_free()
		redeem_coupon_completed.emit(false, 0, "", "Failed to send request")

func _on_redeem_coupon_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle coupon redeem response from server."""
	http_request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		redeem_coupon_completed.emit(false, 0, "", "Connection failed")
		return

	var body_text = body.get_string_from_utf8()
	var json = JSON.new()
	if json.parse(body_text) != OK:
		redeem_coupon_completed.emit(false, 0, "", "Invalid server response")
		return

	var response = json.get_data()
	if not response is Dictionary:
		redeem_coupon_completed.emit(false, 0, "", "Invalid server response format")
		return

	if response.has("mushrooms"):
		var mushrooms = int(response.get("mushrooms", 0))
		redeem_coupon_completed.emit(true, mushrooms, "success", "")
		return

	var status = str(response.get("status", ""))
	if status != "":
		redeem_coupon_completed.emit(false, 0, status, "")
		return

	if response.has("error"):
		redeem_coupon_completed.emit(false, 0, "", str(response.get("error", "Unknown error")))
		return

	if response_code >= 400:
		redeem_coupon_completed.emit(false, 0, "", "Redeem failed (HTTP " + str(response_code) + ")")
		return

	redeem_coupon_completed.emit(false, 0, "", "Unexpected server response")

# ============================================
# Character Management Actions
# ============================================

func _faction_id_to_name(faction: int) -> String:
	match faction:
		1:
			return "order"
		2:
			return "guild"
		3:
			return "companions"
		_:
			return "unknown"

func create_character(character_name: String, faction: int, avatar: Array, vip: bool = false):
	"""
	Create a new character on the selected server
	character_name: Character name
	faction: Faction/guild ID
	avatar: Array of avatar customization IDs [face, hair, eyes, nose, mouth, brows, ears, special]
	vip: VIP status (optional, default false)
	
	Emits create_character_completed signal with:
	- success: bool - whether creation was successful
	- character_id: int - the new character's ID on success
	- error: String - error message on failure
	"""
	var http_request = _create_http_request()
	http_request.request_completed.connect(_on_create_character_completed.bind(http_request))
	last_create_character_response = {}
	
	var payload = {
		"name": character_name,
		"faction": faction,
		"avatar": avatar,
		"vip": vip
	}
	var _faction_name = _faction_id_to_name(faction)
	
	var json_payload = JSON.stringify(payload)
	var url = base_url + "/create-character"
	
	var error = http_request.request(url, _get_headers(true), HTTPClient.METHOD_POST, json_payload)
	
	if error != OK:
		http_request.queue_free()
		last_create_character_response = {}
		create_character_completed.emit(false, 0, "Failed to send request")

func _on_create_character_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http_request: HTTPRequest):
	"""Handle create character response from server"""
	http_request.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		last_create_character_response = {}
		create_character_completed.emit(false, 0, "Connection failed")
		return
	
	var body_text = body.get_string_from_utf8()
	
	if response_code != 200:
		var error_msg = "Character creation failed (HTTP " + str(response_code) + ")"
		# Try to parse error message from response
		var err_json = JSON.new()
		if err_json.parse(body_text) == OK:
			var err_response = err_json.get_data()
			if err_response is Dictionary and err_response.has("error"):
				error_msg = err_response["error"]
		last_create_character_response = {}
		create_character_completed.emit(false, 0, error_msg)
		return
	
	# Parse successful response
	var json = JSON.new()
	if json.parse(body_text) != OK:
		last_create_character_response = {}
		create_character_completed.emit(false, 0, "Invalid server response")
		return
	
	var response = json.get_data()
	if not response is Dictionary or not response.has("character_id"):
		last_create_character_response = {}
		create_character_completed.emit(false, 0, "Invalid server response format")
		return
	
	var character_id = response["character_id"]
	last_create_character_response = response.duplicate(true)
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
