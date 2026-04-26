extends Button

# Player card for character selection in lobby

signal character_selected(character_id: int, server_id: int)

var character_id: int = 0
var server_id: int = 0
var character_data: Dictionary = {}

@onready var name_label = $HBox/Info/NameLabel
@onready var meta_label = $HBox/Info/MetaLabel
@onready var avatar = $HBox/AvatarContainer/Avatar

func _ready():
	# Connect button pressed signal
	pressed.connect(_on_pressed)

func setup(character: Dictionary, srv_id: int = 0):
	"""Setup the player card with character data."""
	character_data = character
	character_id = character.get("character_id", 0)
	server_id = srv_id
	
	# Set labels
	if name_label:
		var vip_badge = " [VIP]" if character.get("vip", false) else ""
		name_label.text = character.get("name", "Unknown") + vip_badge

	if meta_label:
		var faction_name = _faction_to_name(int(character.get("faction", 0)))
		var rank = int(character.get("rank", 0))
		var rank_text = "#" + str(rank) if rank > 0 else "Unranked"
		meta_label.text = faction_name + " | Rank " + rank_text
	
	# Setup avatar with character's cosmetic IDs
	if avatar and character.has("avatar"):
		var avatar_data = character.get("avatar", [40, 48, 33, 88, 80, 0, 0, 0])
		var ids = {
			"face": avatar_data[0] if avatar_data.size() > 0 else 40,
			"hair": avatar_data[1] if avatar_data.size() > 1 else 48,
			"eyes": avatar_data[2] if avatar_data.size() > 2 else 33,
			"nose": avatar_data[3] if avatar_data.size() > 3 else 88,
			"mouth": avatar_data[4] if avatar_data.size() > 4 else 80,
			"brows": avatar_data[5] if avatar_data.size() > 5 else 0,
			"ears": avatar_data[6] if avatar_data.size() > 6 else 0,
			"special": avatar_data[7] if avatar_data.size() > 7 else 0
		}
		avatar.set_avatar_ids(ids)

func _faction_to_name(faction: int) -> String:
	match faction:
		1:
			return "Order"
		2:
			return "Guild"
		3:
			return "Companions"
		_:
			return "Unknown"

func _on_pressed():
	"""Handle button press"""
	print("Player card pressed for character ID: ", character_id, " on server: ", server_id)
	character_selected.emit(character_id, server_id)
