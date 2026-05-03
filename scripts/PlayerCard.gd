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
	
	# Setup avatar with character's cosmetic IDs. Supports both array and dictionary server shapes.
	if avatar:
		avatar.set_avatar_ids(_extract_avatar_ids(character))

func _extract_avatar_ids(character: Dictionary) -> Dictionary:
	var defaults = {
		"face": 40,
		"hair": 48,
		"eyes": 33,
		"nose": 88,
		"mouth": 80,
		"brows": 0,
		"ears": 0,
		"special": 0
	}

	if character.has("avatar"):
		var raw_avatar = character.get("avatar")
		if raw_avatar is Array:
			var arr: Array = raw_avatar
			return {
				"face": int(arr[0]) if arr.size() > 0 else defaults.face,
				"hair": int(arr[1]) if arr.size() > 1 else defaults.hair,
				"eyes": int(arr[2]) if arr.size() > 2 else defaults.eyes,
				"nose": int(arr[3]) if arr.size() > 3 else defaults.nose,
				"mouth": int(arr[4]) if arr.size() > 4 else defaults.mouth,
				"brows": int(arr[5]) if arr.size() > 5 else defaults.brows,
				"ears": int(arr[6]) if arr.size() > 6 else defaults.ears,
				"special": int(arr[7]) if arr.size() > 7 else defaults.special
			}
		if raw_avatar is Dictionary:
			var dict_avatar: Dictionary = raw_avatar
			return {
				"face": int(dict_avatar.get("face", defaults.face)),
				"hair": int(dict_avatar.get("hair", defaults.hair)),
				"eyes": int(dict_avatar.get("eyes", defaults.eyes)),
				"nose": int(dict_avatar.get("nose", defaults.nose)),
				"mouth": int(dict_avatar.get("mouth", defaults.mouth)),
				"brows": int(dict_avatar.get("brows", defaults.brows)),
				"ears": int(dict_avatar.get("ears", defaults.ears)),
				"special": int(dict_avatar.get("special", defaults.special))
			}

	return {
		"face": int(character.get("avatar_face", defaults.face)),
		"hair": int(character.get("avatar_hair", defaults.hair)),
		"eyes": int(character.get("avatar_eyes", defaults.eyes)),
		"nose": int(character.get("avatar_nose", defaults.nose)),
		"mouth": int(character.get("avatar_mouth", defaults.mouth)),
		"brows": int(character.get("avatar_brows", defaults.brows)),
		"ears": int(character.get("avatar_ears", defaults.ears)),
		"special": int(character.get("avatar_special", defaults.special))
	}

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
