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
	

