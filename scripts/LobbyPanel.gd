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

func _ready():
	# Start loading databases in background
	_load_databases_async()
	setup_ui()
	connect_social_buttons()

func _load_databases_async():
	"""Load databases in background while user looks at character list"""
	print("Loading databases in background...")
	GameInfo.load_databases()
	databases_loaded = true
	print("Databases ready!")

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
	
	# Wait for databases if they're still loading
	if not databases_loaded:
		print("Waiting for databases to finish loading...")
		while not databases_loaded:
			await get_tree().process_frame
	
	# Load all character data
	GameInfo.load_all_characters(Websocket.mock_characters)
	
	# Select this character
	GameInfo.select_character(character_id)
	
	print("Switching to game scene...")
	# Switch to game scene
	get_tree().change_scene_to_file("res://Scenes/game.tscn")

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
	

