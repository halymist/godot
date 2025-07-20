extends Node

func _ready():
	print("Websocket ready!")

# Mock data for development/testing
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
	"talent_points": 10,
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
			"item_name": "Simple helmet",
			"type": "Head",
			"subtype": "",
			"armor": 0,
			"strength": 5,
			"constitution": 0,
			"dexterity": 0,
			"luck": 0,
			"damage_min": 8,
			"damage_max": 12,
			"asset_id": 1,
			"effect_name": "",
			"effect_description": "",
			"effect_factor": 0.0,
			"quality": 1,
			"price": 100
		},
		{
			"id": 2,
			"bag_slot_id": 1,
			"item_name": "Chestplate",
			"type": "Chest",
			"subtype": "",
			"armor": 0,
			"strength": 20,
			"constitution": 20,
			"dexterity": 0,
			"luck": 0,
			"damage_min": 0,
			"damage_max": 0,
			"asset_id": 2,
			"effect_name": "Heal",
			"effect_description": "Restores 50 HP",
			"effect_factor": 50.0,
			"quality": 1,
			"price": 25
		},
		{
			"id": 3,
			"bag_slot_id": 11,
			"item_name": "Helmet",
			"type": "Head",
			"subtype": "",
			"armor": 0,
			"strength": 0,
			"constitution": 0,
			"dexterity": 0,
			"luck": 0,
			"damage_min": 0,
			"damage_max": 0,
			"asset_id": 1,
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
			"asset_id": 8,
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
			"points": 1
		},
		{
			"talent_id": 2,
			"points": 1
		}
	]
}
