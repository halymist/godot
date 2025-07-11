extends Node

# Character data loader - loads data into GameInfo singleton
# This script handles loading data from server/mock data into the persistent GameInfo

func _ready():
	# Wait one frame to ensure GameInfo AutoLoad is ready
	await get_tree().process_frame
	# Auto-load player data on start
	load_init(GameInfo.mock_character_data)

# Main function to load and initialize player data into GameInfo
func load_init(character_data: Dictionary):
	print("Loading player data into GameInfo...")
	
	# Copy basic player stats into GameInfo
	GameInfo.current_player.name = character_data.get("name", "")
	GameInfo.player_gold = character_data.get("gold", 0)  # This will emit signal
	GameInfo.player_currency = character_data.get("currency", 0)  # This will emit signal
	GameInfo.current_player.location = character_data.get("location", "")
	GameInfo.current_player.strength = character_data.get("strength", 0)
	GameInfo.current_player.constitution = character_data.get("constitution", 0)
	GameInfo.current_player.dexterity = character_data.get("dexterity", 0)
	GameInfo.current_player.luck = character_data.get("luck", 0)
	GameInfo.current_player.armor = character_data.get("armor", 0)
	GameInfo.current_player.talent_points = character_data.get("talent_points", 0)
	GameInfo.current_player.perk_points = character_data.get("perk_points", 0)
	GameInfo.current_player.dungeon = character_data.get("dungeon", false)
	GameInfo.current_player.traveling = character_data.get("traveling", null)
	GameInfo.current_player.destination = character_data.get("destination", null)
	GameInfo.current_player.slide = character_data.get("slide", 1)
	GameInfo.current_player.slides = character_data.get("slides", null)
	
	# Load items from bag slots into GameInfo
	GameInfo.current_player.bag_slots = []
	load_items(character_data.get("bag_slots", []), GameInfo.current_player.bag_slots)
	
	# Load perks into GameInfo
	GameInfo.current_player.perks = []
	load_perks(character_data.get("perks", []), GameInfo.current_player.perks)
	
	# Load talents into GameInfo
	GameInfo.current_player.talents = []
	load_talents(character_data.get("talents", []), GameInfo.current_player.talents)
	
	print("Player data loaded successfully!")
	print("Player: ", GameInfo.current_player.name)
	print("Gold: ", GameInfo.current_player.gold)
	print("Items: ", GameInfo.current_player.bag_slots.size())
	print("Perks: ", GameInfo.current_player.perks.size())
	print("Talents: ", GameInfo.current_player.talents.size())
	
	# Emit signals from GameInfo
	GameInfo.on_player_data_loaded.emit()
	GameInfo.stats_changed.emit(GameInfo.get_player_stats())

# Load items into the player's bag (simplified version without asset downloading)
func load_items(item_data_array: Array, target_bag_slots: Array):
	print("Loading ", item_data_array.size(), " items...")
	
	for item_data in item_data_array:
		var item = {
			"id": item_data.get("id", 0),
			"bag_slot_id": item_data.get("bag_slot_id", 0),
			"item_name": item_data.get("item_name", ""),
			"type": item_data.get("type", ""),
			"subtype": item_data.get("subtype", ""),
			"armor": item_data.get("armor", 0),
			"strength": item_data.get("strength", 0),
			"constitution": item_data.get("constitution", 0),
			"dexterity": item_data.get("dexterity", 0),
			"luck": item_data.get("luck", 0),
			"damage_min": item_data.get("damage_min", 0),
			"damage_max": item_data.get("damage_max", 0),
			"asset_id": item_data.get("asset_id", 0),
			"effect_name": item_data.get("effect_name", ""),
			"effect_description": item_data.get("effect_description", ""),
			"effect_factor": item_data.get("effect_factor", 0.0),
			"quality": item_data.get("quality", 1),
			"price": item_data.get("price", 0)
		}
		target_bag_slots.append(item)

# Load perks (simplified version without asset downloading)
func load_perks(perk_data_array: Array, target_perks: Array):
	print("Loading ", perk_data_array.size(), " perks...")
	
	for perk_data in perk_data_array:
		var perk = {
			"perk_name": perk_data.get("perk_name", ""),
			"active": perk_data.get("active", false),
			"description": perk_data.get("description", ""),
			"asset_id": perk_data.get("asset_id", 0),
			"slot": perk_data.get("slot", 0),
			"effect1": perk_data.get("effect1", ""),
			"factor1": perk_data.get("factor1", 0.0),
			"effect2": perk_data.get("effect2", ""),
			"factor2": perk_data.get("factor2", 0.0)
		}
		target_perks.append(perk)

# Load talents
func load_talents(talent_data_array: Array, target_talents: Array):
	print("Loading ", talent_data_array.size(), " talents...")
	
	for talent_data in talent_data_array:
		var talent = {
			"talent_id": talent_data.get("talent_id", 0),
			"points": talent_data.get("points", 0)
		}
		target_talents.append(talent)
