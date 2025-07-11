extends Node

# Persistent game data manager - AutoLoad
# This holds all player data permanently, separate from UI

# Signals for UI updates (like Unity events)
signal gold_changed(new_gold)
signal currency_changed(new_currency)
signal stats_changed(stats)
signal on_player_data_loaded
signal current_panel_changed(new_panel)  # Signal for panel switching

# Current player data structure
var current_player = {}

# UI state tracking
var current_panel: Control = null:
	set(value):
		current_panel = value
		current_panel_changed.emit(value)

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

# Mock data arrays (later to be replaced with server data)
var mock_character_data = {
	"name": "TestPlayer",
	"gold": 1000,
	"currency": 50,
	"location": "tavern",
	"strength": 15,
	"constitution": 12,
	"dexterity": 18,
	"luck": 10,
	"armor": 5,
	"talent_points": 3,
	"perk_points": 2,
	"dungeon": false,
	"traveling": null,
	"destination": null,
	"slide": 1,
	"slides": null,
	"bag_slots": [
		{
			"id": 1,
			"bag_slot_id": 0,
			"item_name": "Iron Sword",
			"type": "Weapon",
			"subtype": "Sword",
			"armor": 0,
			"strength": 5,
			"constitution": 0,
			"dexterity": 0,
			"luck": 0,
			"damage_min": 8,
			"damage_max": 12,
			"asset_id": 101,
			"effect_name": "",
			"effect_description": "",
			"effect_factor": 0.0,
			"quality": 1,
			"price": 100
		},
		{
			"id": 2,
			"bag_slot_id": 1,
			"item_name": "Health Potion",
			"type": "Consumable",
			"subtype": "Potion",
			"armor": 0,
			"strength": 0,
			"constitution": 0,
			"dexterity": 0,
			"luck": 0,
			"damage_min": 0,
			"damage_max": 0,
			"asset_id": 201,
			"effect_name": "Heal",
			"effect_description": "Restores 50 HP",
			"effect_factor": 50.0,
			"quality": 1,
			"price": 25
		}
	],
	"perks": [
		{
			"perk_name": "Warrior's Might",
			"active": true,
			"description": "Increases strength by 2",
			"asset_id": 301,
			"slot": 1,
			"effect1": "Strength",
			"factor1": 2.0,
			"effect2": "",
			"factor2": 0.0
		}
	],
	"talents": [
		{
			"talent_id": 1,
			"points": 3
		},
		{
			"talent_id": 2,
			"points": 1
		}
	]
}

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

# UI Panel management functions
func set_current_panel(panel: Control):
	current_panel = panel

func get_current_panel() -> Control:
	return current_panel