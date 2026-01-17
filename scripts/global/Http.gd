extends Node

# ============================================
# HTTP AUTOLOAD
# ============================================
# Handles all HTTP communication with the server
# Authentication, character management, and account operations
# Currently prints actions - TODO: Implement actual HTTP requests

# Base URL for the server API
var base_url = "https://api.example.com"  # TODO: Replace with actual server URL

func _ready():
	print("Http ready!")

# ============================================
# HTTP API - Authentication & Account Actions
# ============================================

func send_request(endpoint: String, method: String, payload: Dictionary):
	"""Send an HTTP request to the server (placeholder for now)"""
	print("[HTTP] ", method, " ", endpoint, " | Payload: ", payload)
	# TODO: Implement actual HTTP request when connected to real server
	# HTTPRequest node would be created here
	# Handle response callbacks

# ============================================
# Authentication Actions
# ============================================

func login(auth_type: String, username: String = "", password: String = ""):
	"""
	Login to account
	auth_type: Authentication method (e.g., "google", "mail", "facebook")
	username: Optional - username/email for certain auth types
	password: Optional - password for certain auth types
	
	Response on success: mock_lobby_data structure with account info and server list
	Response on failure: error message
	"""
	var payload = {
		"auth_type": auth_type
	}
	if username != "":
		payload["username"] = username
	if password != "":
		payload["password"] = password
	
	send_request("/auth/login", "POST", payload)
	
	# TODO: On success, parse response and return lobby data
	# For now, return mock data from Websocket
	return Websocket.mock_lobby_data

func register(auth_type: String, username: String = "", password: String = ""):
	"""
	Register new account
	auth_type: Authentication method (e.g., "google", "mail", "facebook")
	username: Optional - username/email for certain auth types
	password: Optional - password for certain auth types
	
	Response: success/failure message
	"""
	var payload = {
		"auth_type": auth_type
	}
	if username != "":
		payload["username"] = username
	if password != "":
		payload["password"] = password
	
	send_request("/auth/register", "POST", payload)

func logout():
	"""
	Logout from current account
	
	Response: success confirmation
	"""
	send_request("/auth/logout", "POST", {})

func reset_password(email: String):
	"""
	Send password reset email to the provided email address
	email: Email address to send password reset link to
	
	Response: success/failure confirmation
	"""
	var payload = {
		"email": email
	}
	
	send_request("/auth/reset-password", "POST", payload)

# ============================================
# Character Management Actions
# ============================================

func create_character(character_name: String, guild: int, avatar: Array, vip: bool = false):
	"""
	Create a new character on the selected server
	character_name: Character name
	guild: Guild/faction ID
	avatar: Array of avatar customization IDs [face, hair, eyes, nose, mouth]
	vip: VIP status (optional, default false)
	
	Response: success/failure with character data or error message
	"""
	var payload = {
		"name": character_name,
		"guild": guild,
		"avatar": avatar,  # [face, hair, eyes, nose, mouth]
		"vip": vip
	}
	
	send_request("/character/create", "POST", payload)

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
