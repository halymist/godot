extends Control

# Lobby panel for character selection and account management
@export var characters_container: VBoxContainer
@export var create_new_button: Button
@export var logout_button: Button
@export var email_button: TextureButton
@export var google_button: TextureButton
@export var google_play_button: TextureButton
@export var apple_button: TextureButton
@export var discord_button: TextureButton
@export var facebook_button: TextureButton
@export var add_method_button: Button
@export var add_method_panel: Control
@export var social_discord_button: TextureButton
@export var social_instagram_button: TextureButton
@export var social_twitter_button: TextureButton
@export var social_facebook_button: TextureButton
@export var character_info_panel: Control
@export var avatar_creation_panel: Panel

# Account info labels
@export var account_created_label: Label
@export var email_label: Label
@export var mushroom_value_label: Label
@export var new_server_countdown_label: Label
@export var new_server_date_label: Label

# Preload the player card scene
const PlayerCard = preload("res://Scenes/playercard.tscn")
const ServerHeader = preload("res://Scenes/server_header.tscn")

# Social media URLs
const SOCIAL_URLS = {
	"discord": "https://discord.gg/yourgame",
	"instagram": "https://instagram.com/yourgame",
	"twitter": "https://twitter.com/yourgame",
	"facebook": "https://facebook.com/yourgame"
}

enum LobbyPrepareState { IDLE, PREPARING, READY, FAILED }
enum CharacterFlowState { IDLE, CREATING, ENTERING_EXISTING, ENTERING_CREATED }

var game_scene_loaded = false
var game_scene_preload_started = false
var game_scene: PackedScene = null
var _selected_server_day: int = 0  # Server day for selected character's server
var _lobby_prepare_state: LobbyPrepareState = LobbyPrepareState.IDLE
var _character_flow_state: CharacterFlowState = CharacterFlowState.IDLE
var _countdown_timer: Timer = null

signal lobby_ready

func is_lobby_ready() -> bool:
	return _lobby_prepare_state == LobbyPrepareState.READY

func _ready():
	print("LobbyPanel: _ready() called")
	# Connect buttons in _ready (they exist when scene loads)
	create_new_button.pressed.connect(_on_create_new_character)
	logout_button.pressed.connect(_on_logout)
	email_button.pressed.connect(_show_login_with_method.bind("email"))
	google_button.pressed.connect(_show_login_with_method.bind("google"))
	google_play_button.pressed.connect(_show_login_with_method.bind("google_play"))
	apple_button.pressed.connect(_show_login_with_method.bind("apple"))
	discord_button.pressed.connect(_show_login_with_method.bind("discord"))
	facebook_button.pressed.connect(_show_login_with_method.bind("facebook"))
	add_method_button.pressed.connect(_on_add_method_pressed)
	
	# Close add method panel on overlay click
	if add_method_panel:
		add_method_panel.gui_input.connect(_on_add_panel_overlay_click)
		
		# Connect option buttons
		var methods_grid = add_method_panel.get_node_or_null("Content/MethodsGrid")
		if methods_grid:
			var email_opt = methods_grid.get_node_or_null("EmailOptionButton")
			if email_opt:
				email_opt.pressed.connect(_on_add_method_option.bind("email"))
			var google_opt = methods_grid.get_node_or_null("GoogleOptionButton")
			if google_opt:
				google_opt.pressed.connect(_on_add_method_option.bind("google"))
			var google_play_opt = methods_grid.get_node_or_null("GooglePlayOptionButton")
			if google_play_opt:
				google_play_opt.pressed.connect(_on_add_method_option.bind("google_play"))
			var apple_opt = methods_grid.get_node_or_null("AppleOptionButton")
			if apple_opt:
				apple_opt.pressed.connect(_on_add_method_option.bind("apple"))
			var discord_opt = methods_grid.get_node_or_null("DiscordOptionButton")
			if discord_opt:
				discord_opt.pressed.connect(_on_add_method_option.bind("discord"))
			var facebook_opt = methods_grid.get_node_or_null("FacebookOptionButton")
			if facebook_opt:
				facebook_opt.pressed.connect(_on_add_method_option.bind("facebook"))
	
	# Connect social media buttons
	social_discord_button.pressed.connect(_on_social_pressed.bind("discord"))
	social_instagram_button.pressed.connect(_on_social_pressed.bind("instagram"))
	social_twitter_button.pressed.connect(_on_social_pressed.bind("twitter"))
	social_facebook_button.pressed.connect(_on_social_pressed.bind("facebook"))
	
	# Setup character creation panels
	setup_character_creation()
	
	# Connect to HTTP signals
	Http.create_character_completed.connect(_on_character_created)

func initialize_lobby():
	"""Initialize lobby with server data - called by LoginPanel after successful login or when returning from game"""
	if GameInfo.get_lobby_data().is_empty():
		print("Error: initialize_lobby called but no lobby data available")
		_lobby_prepare_state = LobbyPrepareState.FAILED
		return
	
	print("Initializing lobby with server data...")
	
	# Populate UI with lobby data
	populate_account_info()
	setup_login_methods()
	start_new_server_countdown()
	# Hide character cards until data/cosmetics are fully initialized
	if characters_container:
		characters_container.visible = false

	if _lobby_prepare_state == LobbyPrepareState.PREPARING:
		return

	if _lobby_prepare_state == LobbyPrepareState.READY and GameInfo.databases_loaded:
		_finalize_lobby_ready()
		return

	_prepare_lobby()

func _prepare_lobby():
	_lobby_prepare_state = LobbyPrepareState.PREPARING
	_ensure_game_scene_preload_started()
	var databases_ready = await _ensure_databases_ready()
	if not databases_ready:
		_lobby_prepare_state = LobbyPrepareState.FAILED
		return
	_finalize_lobby_ready()

func _ensure_databases_ready() -> bool:
	"""Download data if needed, then initialize databases."""
	if GameInfo.databases_loaded:
		if avatar_creation_panel and avatar_creation_panel.has_method("on_databases_loaded"):
			avatar_creation_panel.on_databases_loaded()
		return true

	var data_versions = GameInfo.get_lobby_data().get("data_versions", {})

	if data_versions.is_empty():
		print("[Lobby] No data_versions, loading databases immediately")
		GameInfo.load_databases()
		if avatar_creation_panel and avatar_creation_panel.has_method("on_databases_loaded"):
			avatar_creation_panel.on_databases_loaded()
		return GameInfo.databases_loaded
	
	# Check if any downloads are needed
	var needs_download = DataManager.needs_download(data_versions)

	if needs_download:
		print("[Lobby] Downloads needed, syncing data first...")
		# Download data + assets, then load databases
		await DataManager.sync_data(data_versions)
		print("[Lobby] Downloads complete, loading databases...")
		GameInfo.load_databases()
	else:
		print("[Lobby] All data up to date, loading databases...")
		GameInfo.load_databases()

	if avatar_creation_panel and avatar_creation_panel.has_method("on_databases_loaded"):
		avatar_creation_panel.on_databases_loaded()
	return GameInfo.databases_loaded

func _finalize_lobby_ready():
	# Re-refresh character card avatars now that cosmetics_db is available
	add_character_list()
	_refresh_character_avatars()
	if characters_container:
		characters_container.visible = true
	_lobby_prepare_state = LobbyPrepareState.READY
	lobby_ready.emit.call_deferred()

func _ensure_game_scene_preload_started():
	if game_scene_loaded or game_scene_preload_started:
		return
	game_scene_preload_started = true
	_load_game_scene_async()

func _load_game_scene_async():
	"""Load game scene in background"""
	ResourceLoader.load_threaded_request("res://Scenes/game.tscn")
	while true:
		# Stop if node was removed from tree (e.g., during logout)
		if not is_inside_tree():
			return
		
		var status = ResourceLoader.load_threaded_get_status("res://Scenes/game.tscn")
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			game_scene = ResourceLoader.load_threaded_get("res://Scenes/game.tscn")
			game_scene_loaded = true
			break
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
			game_scene_preload_started = false
			break
		await get_tree().process_frame

func _refresh_character_avatars():
	"""Re-trigger avatar rendering on all character cards after cosmetics DB loads"""
	for child in characters_container.get_children():
		if child == create_new_button:
			continue
		if child.has_method("refresh_card_avatar"):
			child.refresh_card_avatar()
		elif child.has_node("HBox/AvatarContainer/Avatar"):
			child.get_node("HBox/AvatarContainer/Avatar").refresh_avatar()

func populate_account_info():
	"""Populate account information from lobby data"""
	var lobby_data = GameInfo.get_lobby_data()
	account_created_label.text = "Account Created: " + _parse_iso_date(lobby_data.get("account_created", ""))
	email_label.text = "Email: " + lobby_data.get("user_email", "")
	mushroom_value_label.text = str(int(lobby_data.get("mushrooms", 0)))
	var new_server_ts = lobby_data.get("new_server_timestamp", "")
	if new_server_ts != null and new_server_ts != "":
		new_server_date_label.text = "(" + _parse_iso_date(new_server_ts) + ")"
	else:
		new_server_date_label.text = ""

func _parse_iso_date(iso_string: String) -> String:
	"""Parse ISO 8601 date to readable format"""
	# Format: 2023-01-15T10:30:00Z -> January 15, 2023
	var parts = iso_string.split("T")[0].split("-")
	if parts.size() >= 3:
		var year = parts[0]
		var month_num = int(parts[1])
		var day = int(parts[2])
		
		var months = ["January", "February", "March", "April", "May", "June", 
					  "July", "August", "September", "October", "November", "December"]
		var month_name = months[month_num - 1] if month_num >= 1 and month_num <= 12 else "Unknown"
		
		return month_name + " " + str(day) + ", " + year
	return iso_string

func start_new_server_countdown():
	"""Start countdown timer for new server"""
	_update_new_server_countdown()
	if _countdown_timer and is_instance_valid(_countdown_timer):
		return
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.timeout.connect(_update_new_server_countdown)
	add_child(_countdown_timer)
	_countdown_timer.start()

func _update_new_server_countdown():
	"""Update the countdown label"""
	var timestamp = GameInfo.get_lobby_data().get("new_server_timestamp", "")
	if timestamp == null or timestamp == "":
		new_server_countdown_label.text = "No upcoming server"
		return
	
	var seconds_remaining = _calculate_seconds_until(timestamp)
	
	if seconds_remaining <= 0:
		new_server_countdown_label.text = "New Server Available!"
		return
	
	var total: int = seconds_remaining
	
	var days := int(total / 86400.0)
	total %= 86400
	
	var hours := int(total / 3600.0)
	
	new_server_countdown_label.text = "New start in: " + str(days) + "d " + str(hours) + "h"

func _calculate_seconds_until(iso_timestamp: String) -> int:
	"""Calculate seconds from now until target timestamp"""
	# Parse ISO 8601: 2026-01-20T12:00:00Z
	var parts = iso_timestamp.replace("Z", "").split("T")
	if parts.size() < 2:
		return 0
	
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	
	if date_parts.size() < 3 or time_parts.size() < 3:
		return 0
	
	var target_dict = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2])
	}
	
	var target_unix = Time.get_unix_time_from_datetime_dict(target_dict)
	var current_unix = Time.get_unix_time_from_system()
	
	return int(target_unix - current_unix)

func setup_character_creation():
	"""Setup character creation panels and signals"""
	character_info_panel.next_pressed.connect(_on_character_info_next)
	character_info_panel.back_pressed.connect(_on_character_info_back)
	avatar_creation_panel.create_character_pressed.connect(_on_create_character_complete)
	avatar_creation_panel.back_pressed.connect(_on_avatar_back)
	avatar_creation_panel.set_creation_mode(true)



func add_character_list():
	"""Add character panels from GameInfo.lobby_data"""
	print("[Lobby] add_character_list called")
	
	# Clear existing server headers and character cards, keep the create button.
	for child in characters_container.get_children():
		if child != create_new_button:
			child.queue_free()

	# Keep the create button pinned to the top of the list.
	if create_new_button:
		characters_container.move_child(create_new_button, 0)

	var server_list = GameInfo.get_server_list()
	print("[Lobby] server_list size: ", server_list.size())
	
	var total_characters = 0
	for server in server_list:
		var characters = server.get("characters", null)
		if characters == null or not (characters is Array):
			characters = []
		if characters.is_empty():
			continue

		print("[Lobby] Server '", server.get("name", "?"), "' has ", characters.size(), " characters")

		# Add one header per server, followed by all characters on that server.
		var header = ServerHeader.instantiate()
		characters_container.add_child(header)
		if header.has_method("setup"):
			header.setup(
				server.get("name", "Unknown"),
				server.get("created_at", 0),
				server.get("current_day", 0),
				characters.size()
			)

		for character in characters:
			total_characters += 1
			var card = PlayerCard.instantiate()
			characters_container.add_child(card)
			var card_data = character.duplicate(true) if character is Dictionary else {}
			# Pass character data; server context is now represented by grouped headers.
			card.setup(card_data, server.get("id", 0))
			# Connect to card's signal with proper signature (character_id, server_id)
			card.character_selected.connect(_on_character_selected)
	
	print("[Lobby] Added ", total_characters, " character cards")

func _on_character_selected(character_id: int, server_id: int):
	"""Handle character selection from player card"""
	if _character_flow_state != CharacterFlowState.IDLE:
		print("Character flow already in progress, ignoring selection")
		return
	await _begin_character_entry(character_id, server_id, CharacterFlowState.ENTERING_EXISTING)

func _begin_character_entry(character_id: int, server_id: int, flow_state: CharacterFlowState):
	if flow_state == CharacterFlowState.IDLE:
		return
	_character_flow_state = flow_state

	# Store the current_day from the server for this character
	_selected_server_day = _get_server_day(server_id)
	
	# Store server created_at for day calculation in TopUI
	GameInfo.server_created_at = _get_server_created_at(server_id)
	print("[Lobby] Selected server_created_at: ", GameInfo.server_created_at, ", server_day: ", _selected_server_day)
	
	print("Character selected in lobby: ", character_id, " on server: ", server_id)
	var resources_ready = await _ensure_ready_for_character_entry()
	if not resources_ready:
		_abort_character_flow()
		return
	
	# Connect to WebSocket and send joinLobby
	print("Connecting to WebSocket...")
	var ws_connected = await Websocket.connect_to_server()
	
	if not ws_connected:
		print("ERROR: Failed to connect to WebSocket server")
		_abort_character_flow()
		return
	
	# Connect to playerData signal
	if not Websocket.player_data_received.is_connected(_on_player_data_received):
		Websocket.player_data_received.connect(_on_player_data_received)
	
	# Send joinLobby request
	Websocket.join_lobby(server_id, character_id, Http.session_id)
	
	# Wait for playerData response (handled in _on_player_data_received)
	print("Waiting for player data from server...")

func _ensure_ready_for_character_entry() -> bool:
	_ensure_game_scene_preload_started()
	while not GameInfo.databases_loaded or not game_scene_loaded:
		if not GameInfo.databases_loaded:
			print("Waiting for databases to finish loading...")
		if not game_scene_loaded:
			print("Waiting for game scene to finish loading...")
		await get_tree().process_frame
	return true

func _on_player_data_received(character_data: Dictionary):
	"""Handle playerData response from WebSocket"""
	print("[Lobby] Received player data, loading character...")
	
	# Disconnect signal to avoid multiple calls
	if Websocket.player_data_received.is_connected(_on_player_data_received):
		Websocket.player_data_received.disconnect(_on_player_data_received)
	
	# Keep UI day consistent with selected server list day.
	# Some playerData payloads omit this field or return stale defaults.
	if _selected_server_day > 0:
		character_data["server_day"] = _selected_server_day
	
	# Load character data into GameInfo (replaces mock data)
	GameInfo.load_character_from_server(character_data)
	if GameInfo.current_player and _selected_server_day > 0:
		GameInfo.current_player.server_day = _selected_server_day
	
	print("[Lobby] Character loaded, switching to game scene...")
	var use_dark_transition = _character_flow_state == CharacterFlowState.ENTERING_CREATED
	_character_flow_state = CharacterFlowState.IDLE
	# If create flow already started fade_out, avoid a second fade_out.
	if use_dark_transition:
		# Let SceneTransition (autoload) finish scene swap + fade in,
		# so this flow survives LobbyPanel being freed.
		SceneTransition.change_scene_to_packed_after_dark(game_scene)
	else:
		# Normal selection flow
		SceneTransition.change_scene_to_packed(game_scene)

func _show_login_with_method(method: String):
	"""Show login screen to add/link another account with specified method"""
	print("Link account with: ", method)
	# TODO: Open login panel with specific method pre-selected
	# For now, just show which method was clicked

func _on_logout():
	"""Logout and return to login screen"""
	# Call server logout endpoint
	Http.logout()
	GameInfo.skip_auto_login_once = true
	
	# Clear lobby data
	GameInfo.clear_lobby_data()
	
	# Return to login screen
	SceneTransition.change_scene_to_file("res://Scenes/login.tscn")

func _on_create_new_character():
	"""Show character info panel to start creation flow"""
	if _character_flow_state != CharacterFlowState.IDLE:
		return
	visible = false
	character_info_panel.visible = true

func _on_character_info_next():
	"""User completed character info, show avatar creation"""
	character_info_panel.visible = false
	avatar_creation_panel.visible = true
	# Refresh preview now that cosmetics DB is available
	if avatar_creation_panel.has_method("_refresh_preview"):
		avatar_creation_panel._refresh_preview()

func _on_character_info_back():
	"""Go back from character info to lobby"""
	character_info_panel.visible = false
	visible = true

func _on_avatar_back():
	"""Go back from avatar to character info"""
	avatar_creation_panel.visible = false
	character_info_panel.visible = true

func _on_create_character_complete():
	"""User completed avatar creation, create the character"""
	if _character_flow_state != CharacterFlowState.IDLE:
		return
	_character_flow_state = CharacterFlowState.CREATING

	# Optimistic UX: start transition immediately, before server response.
	SceneTransition.fade_out()

	var character_data = character_info_panel.get_character_data()
	var avatar_data = avatar_creation_panel.get_avatar_data()
	
	# Build avatar array [face, hair, eyes, nose, mouth, brows, ears, special]
	var avatar_array = [
		avatar_data["face"],
		avatar_data["hair"],
		avatar_data["eyes"],
		avatar_data["nose"],
		avatar_data["mouth"],
		avatar_data["brows"],
		avatar_data["ears"],
		avatar_data["special"]
	]
	
	# Send character creation request to server
	Http.create_character(
		character_data["name"],
		character_data["faction"],
		avatar_array,
		character_data["vip"]
	)

func _on_character_created(success: bool, character_id: int, error: String):
	"""Handle character creation response from server"""
	if _character_flow_state != CharacterFlowState.CREATING:
		return

	if not success:
		print("[Lobby] Character creation failed: ", error)
		_abort_character_flow()
		# TODO: Show error message to user
		return
	
	print("[Lobby] Character created successfully with ID: ", character_id)

	var create_response: Dictionary = Http.last_create_character_response
	var server_id := _extract_server_id_from_create_response(create_response)

	if server_id <= 0:
		print("[Lobby] Missing server_id in create-character response; cannot auto-login")
		_abort_character_flow()
		return

	print("[Lobby] Auto-logging into newly created character ", character_id, " on server ", server_id)
	await _begin_character_entry(character_id, server_id, CharacterFlowState.ENTERING_CREATED)

func _abort_character_flow():
	"""Reset lobby UI after a failed or canceled character flow."""
	var was_create_flow = _character_flow_state == CharacterFlowState.CREATING or _character_flow_state == CharacterFlowState.ENTERING_CREATED
	_character_flow_state = CharacterFlowState.IDLE
	if was_create_flow:
		_cancel_character_transition_to_menu()

func _cancel_character_transition_to_menu():
	"""Fallback from optimistic create transition back to create menu UI."""
	character_info_panel.visible = false
	avatar_creation_panel.visible = true
	visible = false
	SceneTransition.fade_in()

func _extract_server_id_from_create_response(response: Dictionary) -> int:
	"""Read server_id from backend create-character response in multiple shapes."""
	if response.is_empty():
		return 0

	if response.has("server_id"):
		return int(response.get("server_id", 0))
	if response.has("serverId"):
		return int(response.get("serverId", 0))

	var server = response.get("server", null)
	if server is Dictionary:
		if server.has("id"):
			return int(server.get("id", 0))
		if server.has("server_id"):
			return int(server.get("server_id", 0))

	var character = response.get("character", null)
	if character is Dictionary:
		if character.has("server_id"):
			return int(character.get("server_id", 0))
		if character.has("serverId"):
			return int(character.get("serverId", 0))

	return 0

func _get_server_day(server_id: int) -> int:
	"""Get current_day from server list for the given server_id"""
	var server_list = GameInfo.get_server_list()
	for server in server_list:
		if int(server.get("id", 0)) == int(server_id):
			return int(server.get("current_day", 0))
	return 0

func _get_server_created_at(server_id: int) -> int:
	"""Get created_at timestamp from server list for the given server_id"""
	var server_list = GameInfo.get_server_list()
	for server in server_list:
		if int(server.get("id", 0)) == int(server_id):
			return int(server.get("created_at", 0))
	return 0

func _on_social_pressed(platform: String):
	"""Open social media link"""
	if platform in SOCIAL_URLS:
		OS.shell_open(SOCIAL_URLS[platform])

func setup_login_methods():
	"""Show only connected login methods"""
	var connected_methods = GameInfo.get_lobby_data().get("user_connected_methods", [])
	
	# Map method names to buttons
	var method_buttons = {
		"mail": email_button,
		"email": email_button,
		"google": google_button,
		"google_play": google_play_button,
		"apple": apple_button,
		"discord": discord_button,
		"facebook": facebook_button
	}
	
	# Hide all method buttons first
	for button in method_buttons.values():
		if button:
			button.visible = false
	
	# Show only connected methods
	for method in connected_methods:
		if method in method_buttons and method_buttons[method]:
			method_buttons[method].visible = true

func _on_add_method_pressed():
	"""Show panel to add new login method (only unconnected ones)"""
	if not add_method_panel:
		return
	
	var connected_methods = GameInfo.get_lobby_data().get("user_connected_methods", [])
	var methods_grid = add_method_panel.get_node_or_null("Content/MethodsGrid")
	
	if not methods_grid:
		print("Error: MethodsGrid not found")
		return
	
	# Map method names to option buttons
	var method_buttons = {
		"email": "EmailOptionButton",
		"mail": "EmailOptionButton",
		"google": "GoogleOptionButton",
		"google_play": "GooglePlayOptionButton",
		"apple": "AppleOptionButton",
		"discord": "DiscordOptionButton",
		"facebook": "FacebookOptionButton"
	}
	
	# Hide all option buttons first
	for button_name in method_buttons.values():
		var button = methods_grid.get_node_or_null(button_name)
		if button:
			button.visible = false
	
	# Show only methods that are NOT connected
	var all_methods = ["email", "google", "google_play", "apple", "discord", "facebook"]
	for method in all_methods:
		if method not in connected_methods and method != "mail":
			var button_name = method_buttons.get(method, "")
			if button_name:
				var button = methods_grid.get_node_or_null(button_name)
				if button:
					button.visible = true
	
	# Handle "mail" mapping to "email"
	if "mail" in connected_methods:
		var email_btn = methods_grid.get_node_or_null("EmailOptionButton")
		if email_btn:
			email_btn.visible = false
	
	add_method_panel.visible = true

func _on_add_panel_overlay_click(event: InputEvent):
	"""Close add method panel when clicking overlay"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if add_method_panel:
			add_method_panel.visible = false

func _on_add_method_option(method: String):
	"""Handle adding a new login method (placeholder)"""
	print("Add login method: ", method)
	if add_method_panel:
		add_method_panel.visible = false
	# TODO: Implement actual method linking
