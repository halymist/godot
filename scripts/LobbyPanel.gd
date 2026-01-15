extends Panel

# Lobby panel for character selection and account management
@export var characters_container: VBoxContainer
@export var discord_button: TextureButton
@export var instagram_button: TextureButton
@export var twitter_button: TextureButton

# Social media URLs
const DISCORD_URL = "https://discord.gg/your-discord-invite"
const INSTAGRAM_URL = "https://instagram.com/your-username"
const TWITTER_URL = "https://twitter.com/your-username"

# Preload the player card scene
const PlayerCard = preload("res://Scenes/playercard.tscn")

var databases_loaded = false
var game_scene_loaded = false
var game_scene: PackedScene = null

func _ready():
	# Start loading databases and game scene in background
	_load_databases_async()
	_load_game_scene_async()
	setup_ui()
	connect_social_buttons()

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
	if discord_button:
		discord_button.pressed.connect(_on_discord_pressed)
	if instagram_button:
		instagram_button.pressed.connect(_on_instagram_pressed)
	if twitter_button:
		twitter_button.pressed.connect(_on_twitter_pressed)

func setup_ui():
	"""Initialize the lobby UI with character cards"""
	# Setup character list
	if characters_container:
		add_character_list()

func add_character_list():
	"""Add character panels from Websocket.mock_characters"""
	# Load characters from Websocket
	for character in Websocket.mock_characters:
		var card = PlayerCard.instantiate()
		characters_container.add_child(card)
		card.setup(character)
		# Connect to card's signal
		card.character_selected.connect(_on_character_selected)

func _on_character_selected(character_id: int):
	"""Handle character selection from player card"""
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
	
