extends PanelContainer

# Player card for character selection in lobby

signal character_selected(character_id: int)

var character_id: int = 0
var character_data: Dictionary = {}

@onready var name_label = $HBox/Info/NameLabel
@onready var server_label = $HBox/Info/ServerLabel

func _ready():
	# Make the entire card clickable
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(character: Dictionary):
	"""Setup the player card with character data"""
	character_data = character
	character_id = character.character_id
	
	# Set labels
	if name_label:
		name_label.text = character.name + " (#" + str(character.rank) + ")"
	
	if server_label:
		var server_name = character.server_timezone.split("/")[1]  # Extract city from timezone
		server_label.text = "Server: " + server_name + " (Day " + str(character.server_day) + ")"

func _gui_input(event: InputEvent):
	"""Handle mouse clicks on the card"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Selected character ID: ", character_id)
			character_selected.emit(character_id)
			# TODO: Load character world data
