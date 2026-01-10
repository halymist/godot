extends Panel

# Lobby panel for character selection and account management

@export var characters_container: VBoxContainer

# Preload the player card scene
const PlayerCard = preload("res://Scenes/playercard.tscn")

func _ready():
	setup_ui()

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
	

