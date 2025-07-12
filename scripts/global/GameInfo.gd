extends Node
@export var fallback_folder: String = "res://assets/images/fallback"
# Persistent game data manager - AutoLoad
# This holds all player data permanently, separate from UI

# Signals for UI updates
signal gold_changed(new_gold)
signal currency_changed(new_currency)
signal stats_changed(stats)
signal on_player_data_loaded
signal current_panel_changed(new_panel)
signal current_panel_overlay_changed(new_overlay) # panels that partially cover the screen

func _ready():
	print("GameInfo ready!")
	load_player_data(Websocket.mock_character_data)

var current_player = {}

var current_panel: Control = null:
	set(value):
		current_panel = value
		current_panel_changed.emit(value)

var current_panel_overlay: Control = null:
	set(value):
		current_panel_overlay = value
		current_panel_overlay_changed.emit(value)

# Properties with getters/setters that emit signals
var player_gold: int = 0:
	set(value):
		player_gold = value
		current_player.gold = value
		gold_changed.emit(value)

var player_currency: int = 0:
	set(value):
		player_currency = value
		current_player.currency = value
		currency_changed.emit(value)


# Helper functions to modify values and emit signals
func add_gold(amount: int):
	player_gold += amount

func add_currency(amount: int):
	player_currency += amount



# Helper function to get player stats for UI
func get_player_stats() -> Dictionary:
	return {
		"name": current_player.name,
		"gold": player_gold,
		"currency": player_currency,
		"strength": current_player.strength,
		"stamina": current_player.constitution,  # Map constitution to stamina for UI
		"agility": current_player.dexterity,     # Map dexterity to agility for UI
		"luck": current_player.luck,
		"armor": current_player.armor,
		"talent_points": current_player.talent_points,
		"perk_points": current_player.perk_points
	}

# Helper to get a texture for an asset_id from fallback folder
func get_fallback_texture(asset_id: int) -> Texture2D:
	var path = "%s/%d.png" % [fallback_folder, asset_id]
	print("Checking for fallback texture at: ", path)
	if ResourceLoader.exists(path):
		print("Loading fallback texture from: ", path)
		return load(path)
	return null

# Example: assign texture reference to item dict (call this after loading items)
func assign_item_textures(bag_slots: Array):
	for item in bag_slots:
		print("Assigning texture for item: ", item.get("item_name", "Unknown"))
		if item.has("asset_id"):
			item["texture"] = get_fallback_texture(item["asset_id"])

# UI Panel management functions
func set_current_panel(panel: Control):
	current_panel = panel

func get_current_panel() -> Control:
	return current_panel

func set_current_panel_overlay(panel: Control):
	current_panel_overlay = panel

func get_current_panel_overlay() -> Control:
	return current_panel_overlay

# Load player data into current_player and assign textures
func load_player_data(character_data: Dictionary):
	print("Loading player data into GameInfo...")
	# Copy basic player stats
	current_player.name = character_data.get("name", "")
	player_gold = character_data.get("gold", 0)
	player_currency = character_data.get("currency", 0)
	current_player.location = character_data.get("location", "")
	current_player.strength = character_data.get("strength", 0)
	current_player.constitution = character_data.get("constitution", 0)
	current_player.dexterity = character_data.get("dexterity", 0)
	current_player.luck = character_data.get("luck", 0)
	current_player.armor = character_data.get("armor", 0)
	current_player.talent_points = character_data.get("talent_points", 0)
	current_player.perk_points = character_data.get("perk_points", 0)
	current_player.dungeon = character_data.get("dungeon", false)
	current_player.traveling = character_data.get("traveling", null)
	current_player.destination = character_data.get("destination", null)
	current_player.slide = character_data.get("slide", 1)
	current_player.slides = character_data.get("slides", null)

	# Load items
	current_player.bag_slots = []
	for item_data in character_data.get("bag_slots", []):
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
		item["texture"] = get_fallback_texture(item["asset_id"])
		current_player.bag_slots.append(item)

	# Load perks
	current_player.perks = []
	for perk_data in character_data.get("perks", []):
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
		perk["texture"] = get_fallback_texture(perk["asset_id"])
		current_player.perks.append(perk)

	# Load talents
	current_player.talents = []
	for talent_data in character_data.get("talents", []):
		var talent = {
			"talent_id": talent_data.get("talent_id", 0),
			"points": talent_data.get("points", 0)
		}
		current_player.talents.append(talent)

	print("Player data loaded successfully!")
	print("Player: ", current_player.name)
	print("Gold: ", current_player.gold)
	print("Items: ", current_player.bag_slots.size())
	print("Perks: ", current_player.perks.size())
	print("Talents: ", current_player.talents.size())

	on_player_data_loaded.emit()
	stats_changed.emit(get_player_stats())