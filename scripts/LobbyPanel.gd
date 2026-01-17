extends Control

# Lobby panel for character selection and account management
@export var characters_container: VBoxContainer
@export var create_new_button: Button
@export var logout_button: Button
@export var discord_button: TextureButton
@export var instagram_button: TextureButton
@export var twitter_button: TextureButton
@export var character_info_panel: Control
@export var avatar_creation_panel: Panel

# Account info labels
@export var account_created_label: Label
@export var email_label: Label
@export var mushroom_value_label: Label
@export var new_server_countdown_label: Label
@export var new_server_date_label: Label

# Social media URLs mapping
const SOCIAL_URLS = {
	"discord": "https://discord.gg/your-discord-invite",
	"instagram": "https://instagram.com/your-username",
	"twitter": "https://twitter.com/your-username"
}

# Preload the player card scene
const PlayerCard = preload("res://Scenes/playercard.tscn")

var databases_loaded = false
var game_scene_loaded = false
var game_scene: PackedScene = null
var loading_in_progress = false  # Prevent multiple character selections while loading

func _ready():
	_load_databases_async()
	_load_game_scene_async()
	# lobby_data should already be loaded by LoginPanel, but ensure it's loaded
	if GameInfo.lobby_data.is_empty():
		GameInfo.load_lobby_data()
	populate_account_info()
	add_character_list()
	setup_character_creation()
	start_new_server_countdown()
	
	# Connect buttons
	create_new_button.pressed.connect(_on_create_new_character)
	logout_button.pressed.connect(_on_logout)
	discord_button.pressed.connect(_on_social_pressed.bind("discord"))
	instagram_button.pressed.connect(_on_social_pressed.bind("instagram"))
	twitter_button.pressed.connect(_on_social_pressed.bind("twitter"))

func _load_databases_async():
	"""Load databases in background"""
	GameInfo.load_databases()
	databases_loaded = true

func _load_game_scene_async():
	"""Load game scene in background"""
	ResourceLoader.load_threaded_request("res://Scenes/game.tscn")
	while true:
		var status = ResourceLoader.load_threaded_get_status("res://Scenes/game.tscn")
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			game_scene = ResourceLoader.load_threaded_get("res://Scenes/game.tscn")
			game_scene_loaded = true
			break
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
			break
		await get_tree().process_frame

func populate_account_info():
	"""Populate account information from lobby data"""
	var lobby_data = GameInfo.lobby_data
	account_created_label.text = "Account Created: " + _parse_iso_date(lobby_data.account_created)
	email_label.text = "Email: " + lobby_data.email
	mushroom_value_label.text = str(lobby_data.mushrooms)
	new_server_date_label.text = "(" + _parse_iso_date(lobby_data.new_server_timestamp) + ")"

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
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_update_new_server_countdown)
	add_child(timer)
	timer.start()

func _update_new_server_countdown():
	"""Update the countdown label"""
	var seconds_remaining = _calculate_seconds_until(GameInfo.lobby_data.new_server_timestamp)
	
	if seconds_remaining <= 0:
		new_server_countdown_label.text = "New Server Available!"
		return
	
	var total: int = seconds_remaining
	
	var days := total / 86400
	total %= 86400
	
	var hours := total / 3600
	
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
	for server in GameInfo.lobby_data.server_list:
		for character_mini in server.characters_mini:
			var card = PlayerCard.instantiate()
			characters_container.add_child(card)
			# Pass minimal character data plus server info for display
			card.setup(character_mini, server.server_name, server.server_start)
			# Connect to card's signal
			card.character_selected.connect(_on_character_selected)

func _on_character_selected(character_id: int):
	"""Handle character selection from player card"""
	# Ignore if already loading a character
	if loading_in_progress:
		print("Character selection already in progress, ignoring click")
		return
	
	loading_in_progress = true
	print("Character selected in lobby: ", character_id)
	
	# Wait for both databases and game scene if they're still loading
	while not databases_loaded or not game_scene_loaded:
		if not databases_loaded:
			print("Waiting for databases to finish loading...")
		if not game_scene_loaded:
			print("Waiting for game scene to finish loading...")
		await get_tree().process_frame
	
	# Load all character data
	GameInfo.load_all_characters(Websocket.mock_characters)
	
	# Select this character
	GameInfo.select_character(character_id)
	
	print("Switching to game scene...")
	# Switch to preloaded game scene (instant!)
	get_tree().change_scene_to_packed(game_scene)

func _on_social_pressed(platform: String):
	"""Open social media link"""
	OS.shell_open(SOCIAL_URLS[platform])

func _on_logout():
	"""Logout and return to login screen"""
	# Clear lobby data to force login
	GameInfo.lobby_data.clear()
	get_tree().change_scene_to_file("res://Scenes/login.tscn")

func _on_create_new_character():
	"""Show character info panel to start creation flow"""
	visible = false
	character_info_panel.visible = true

func _on_character_info_next():
	"""User completed character info, show avatar creation"""
	character_info_panel.visible = false
	avatar_creation_panel.visible = true

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
	var character_data = character_info_panel.get_character_data()
	var avatar_data = avatar_creation_panel.get_avatar_data()
	
	# Build avatar array [face, hair, eyes, nose, mouth]
	var avatar_array = [
		avatar_data["face"],
		avatar_data["hair"],
		avatar_data["eyes"],
		avatar_data["nose"],
		avatar_data["mouth"]
	]
	
	# Send character creation request to server
	Http.create_character(
		character_data["name"],
		character_data["faction"],
		avatar_array,
		character_data["vip"]
	)
	
	avatar_creation_panel.visible = false
	visible = true
