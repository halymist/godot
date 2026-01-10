extends PanelContainer

# Player card for character selection in lobby

var character_id: int = 0
var character_data: Dictionary = {}

@onready var name_label = $HBox/Info/NameLabel
@onready var server_label = $HBox/Info/ServerLabel
@onready var rank_label = $HBox/Info/RankLabel
@onready var stats_label = $HBox/Info/StatsLabel
@onready var select_button = $HBox/SelectButton

func _ready():
	if select_button:
		select_button.pressed.connect(_on_select_pressed)

func setup(character: Dictionary):
	"""Setup the player card with character data"""
	character_data = character
	character_id = character.character_id
	
	# Set labels
	if name_label:
		name_label.text = character.name
	
	if server_label:
		var server_name = character.server_timezone.split("/")[1]  # Extract city from timezone
		server_label.text = "Server: " + server_name + " (Day " + str(character.server_day) + ")"
	
	if rank_label:
		rank_label.text = "Rank: #" + str(character.rank)
	
	if stats_label:
		var stats = character.stats
		var level = stats[0] + stats[1] + stats[2]  # Sum of strength, stamina, agility
		stats_label.text = "Silver: " + str(character.silver) + " | Level: " + str(level)

func _on_select_pressed():
	"""Handle select button press"""
	print("Selected character ID: ", character_id)
	# TODO: Signal to parent or directly load character world
