extends Control

# Lobby panel for character selection and account management
@export var characters_container: VBoxContainer
@export var discord_button: TextureButton
@export var instagram_button: TextureButton
@export var twitter_button: TextureButton
@export var character_info_panel: Control
@export var avatar_creation_panel: Panel

# Social media URLs
const DISCORD_URL = "https://discord.gg/your-discord-invite"
const INSTAGRAM_URL = "https://instagram.com/your-username"
const TWITTER_URL = "https://twitter.com/your-username"

# Preload the player card scene
const PlayerCard = preload("res://Scenes/playercard.tscn")

var databases_loaded = false
var game_scene_loaded = false
var game_scene: PackedScene = null
var loading_in_progress = false  # Prevent multiple character selections while loading

func _ready():
	# Start loading databases and game scene in background
	_load_databases_async()
	_load_game_scene_async()
	add_character_list()
	connect_social_buttons()
	setup_character_creation()

func _load_databases_async():
	"""Load databases in background while user looks at character list"""
	print("Loading databases in background...")
	GameInfo.load_databases()
	databases_loaded = true
	print("Databases ready!")

func _load_game_scene_async():
	"""Load game scene in background while user looks at character list"""
	print("Loading game scene in background...")
	
	# Start loading game scene in background thread
	ResourceLoader.load_threaded_request("res://Scenes/game.tscn")
	
	# Poll until loaded (non-blocking)
	while true:
		var status = ResourceLoader.load_threaded_get_status("res://Scenes/game.tscn")
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			game_scene = ResourceLoader.load_threaded_get("res://Scenes/game.tscn")
			game_scene_loaded = true
			print("Game scene preloaded!")
			break
		elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
			print("ERROR: Failed to load game scene!")
			break
		await get_tree().process_frame

func connect_social_buttons():
	"""Connect social media button signals"""
	discord_button.pressed.connect(_on_discord_pressed)
	instagram_button.pressed.connect(_on_instagram_pressed)
	twitter_button.pressed.connect(_on_twitter_pressed)

func setup_character_creation():
	"""Setup character creation panels and signals"""
	if character_info_panel:
		character_info_panel.next_pressed.connect(_on_character_info_next)
		character_info_panel.back_pressed.connect(_on_character_info_back)
	
	if avatar_creation_panel:
		avatar_creation_panel.create_character_pressed.connect(_on_create_character_complete)
		avatar_creation_panel.back_pressed.connect(_on_avatar_back)
		avatar_creation_panel.set_creation_mode(true)



func add_character_list():
	"""Add character panels from Websocket.mock_characters"""
	# Add "Create New Character" button first
	var create_new = characters_container.get_node("CreateNew")
	if create_new:
		var create_button = create_new.get_node("Label")
		if create_button is Label:
			# Make it clickable by converting parent to button
			var button = Button.new()
			button.custom_minimum_size = Vector2(0, 80)
			button.text = "Create New Character"
			button.pressed.connect(_on_create_new_character)
			create_new.get_parent().add_child(button)
			create_new.get_parent().move_child(button, 0)
			create_new.queue_free()
	
	# Load characters from Websocket
	for character in Websocket.mock_characters:
		var card = PlayerCard.instantiate()
		characters_container.add_child(card)
		card.setup(character)
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

func _on_discord_pressed():
	"""Open Discord link"""
	OS.shell_open(DISCORD_URL)
	print("Opening Discord...")

func _on_instagram_pressed():
	"""Open Instagram link"""
	OS.shell_open(INSTAGRAM_URL)
	print("Opening Instagram...")

func _on_twitter_pressed():
	"""Open Twitter link"""
	OS.shell_open(TWITTER_URL)
	print("Opening Twitter...")

func _on_create_new_character():
	"""Show character info panel to start creation flow"""
	print("Create new character clicked")
	visible = false
	character_info_panel.visible = true

func _on_character_info_next():
	"""User completed character info, show avatar creation"""
	print("Character info complete, showing avatar creation")
	character_info_panel.visible = false
	avatar_creation_panel.visible = true

func _on_character_info_back():
	"""Go back from character info to lobby"""
	print("Going back to lobby from character info")
	character_info_panel.visible = false
	visible = true

func _on_avatar_back():
	"""Go back from avatar to character info"""
	print("Going back to character info from avatar")
	avatar_creation_panel.visible = false
	character_info_panel.visible = true

func _on_create_character_complete():
	"""User completed avatar creation, create the character"""
	var character_data = character_info_panel.get_character_data()
	var avatar_data = avatar_creation_panel.get_avatar_data()
	
	print("Creating character:")
	print("  Name: ", character_data.name)
	print("  Faction: ", character_data.faction)
	print("  VIP: ", character_data.vip)
	print("  Stats: STR:", character_data.strength, " STA:", character_data.stamina, " AGI:", character_data.agility, " LCK:", character_data.luck)
	print("  Avatar: ", avatar_data)
	
	# TODO: Send to server to create character
	# For now, just go back to lobby
	avatar_creation_panel.visible = false
	visible = true
	print("Character created! (mock)")
