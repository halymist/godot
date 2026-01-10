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

func _ready():
	setup_ui()
	connect_social_buttons()

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
	
	# Select this character in GameInfo (this will emit character_changed signal)
	GameInfo.select_character(character_id)
	UIManager.instance.show_panel(UIManager.instance.home_panel)
	# Hide lobby
	visible = false
	
	print("Loaded character: ", GameInfo.current_player.name)

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
	

