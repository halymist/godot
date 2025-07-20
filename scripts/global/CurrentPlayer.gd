class_name CurrentPlayer
extends Player

# CurrentPlayer extends Player with additional fields specific to the current player
# Fields that ArenaOpponent doesn't have

# Current player specific fields
var gold: int = 0
var currency: int = 0
var talent_points: int = 0
var perk_points: int = 0

# Additional world state fields (not in ArenaOpponent)
var location: String = ""
var dungeon: bool = false
var traveling: Variant = null  # Can be bool or null
var destination: Variant = null  # Can be string or null
var slide: int = 1
var slides: Variant = null  # Can be Array or null

func _init(character_data: Dictionary = {}):
	super()  # Call parent constructor
	if not character_data.is_empty():
		load_from_data(character_data)

# Load from local data format (current player data)
func load_from_data(character_data: Dictionary):
	# Load base player fields first
	character_id = character_data.get("character_id", 0)
	name = character_data.get("name", "")
	strength = character_data.get("strength", 0)
	constitution = character_data.get("constitution", 0)
	dexterity = character_data.get("dexterity", 0)
	luck = character_data.get("luck", 0)
	armor = character_data.get("armor", 0)
	
	# Load current player specific fields
	gold = character_data.get("gold", 0)
	currency = character_data.get("currency", 0)
	talent_points = character_data.get("talent_points", 0)
	perk_points = character_data.get("perk_points", 0)
	
	# Load world state fields
	location = character_data.get("location", "")
	dungeon = character_data.get("dungeon", false)
	traveling = character_data.get("traveling", null)
	destination = character_data.get("destination", null)
	slide = character_data.get("slide", 1)
	slides = character_data.get("slides", null)
	
	# Load items, perks, talents
	load_items(character_data.get("bag_slots", []))
	load_perks(character_data.get("perks", []))
	load_talents(character_data.get("talents", []))

func get_player_stats() -> Dictionary:
	var base_stats = get_base_stats()
	base_stats["gold"] = gold
	base_stats["currency"] = currency
	base_stats["talent_points"] = talent_points
	base_stats["perk_points"] = perk_points
	return base_stats
