extends Button

# Player card for character selection in lobby

signal character_selected(character_id: int)

var character_id: int = 0
var character_data: Dictionary = {}

@onready var name_label = $HBox/Info/NameLabel
@onready var server_label = $HBox/Info/ServerLabel
@onready var avatar = $HBox/AvatarContainer/Avatar

func _ready():
	# Connect button pressed signal
	pressed.connect(_on_pressed)

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
	
	# Setup avatar with character's cosmetic IDs
	if avatar and character.has("avatar"):
		var avatar_data = character.avatar  # [face, hair, eyes, nose, mouth]
		if avatar_data.size() >= 5:
			avatar.refresh_avatar(
				avatar_data[0],  # face
				avatar_data[1],  # hair
				avatar_data[2],  # eyes
				avatar_data[3],  # nose
				avatar_data[4]   # mouth
			)

func _on_pressed():
	"""Handle button press"""
	print("Selected character ID: ", character_id)
	character_selected.emit(character_id)
	# TODO: Load character world data
