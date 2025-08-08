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
		},
		{
			"perk_name": "Test",
			"active": false,
			"description": "Increases strength by 10",
			"asset_id": 8,
			"slot": 1,
			"effect1": "Strength",
			"factor1": 10.0,
			"effect2": "",
			"factor2": 0.0
		},
				{
			"perk_name": "Test2",
			"active": false,
			"description": "Increases stamina by 10",
			"asset_id": 8,
			"slot": 2,
			"effect1": "Stamina",
			"factor1": 10.0,
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

# Mock arena opponents data
var mock_arena_opponents = [
	{
		"name": "Goblin Warrior",
		"strength": 12,
		"constitution": 10,
		"dexterity": 14,
		"luck": 8,
		"armor": 3,
		"bag_slots": [
			{
				"id": 11,
				"bag_slot_id": 0,
				"item_name": "Rusty Sword",
				"type": "Weapon",
				"subtype": "Sword",
				"armor": 0,
				"strength": 3,
				"constitution": 0,
				"dexterity": 0,
				"luck": 0,
				"damage_min": 5,
				"damage_max": 8,
				"asset_id": 11,
				"effect_name": "",
				"effect_description": "",
				"effect_factor": 0.0,
				"quality": 1,
				"price": 50
			}
		],
		"perks": [
			{
				"perk_name": "Berserker Rage",
				"active": true,
				"description": "Increases damage when health is low",
				"asset_id": 5,
				"slot": 1,
				"effect1": "Strength",
				"factor1": 3.0,
				"effect2": "",
				"factor2": 0.0
			}
		],
		"talents": [
			{
				"talent_id": 1,
				"points": 2
			}
		]
	},
	{
		"name": "Orc Brute",
		"strength": 18,
		"constitution": 16,
		"dexterity": 8,
		"luck": 6,
		"armor": 8,
		"bag_slots": [
			{
				"id": 12,
				"bag_slot_id": 0,
				"item_name": "Heavy Axe",
				"type": "Weapon",
				"subtype": "Axe",
				"armor": 0,
				"strength": 5,
				"constitution": 0,
				"dexterity": -2,
				"luck": 0,
				"damage_min": 8,
				"damage_max": 15,
				"asset_id": 12,
				"effect_name": "",
				"effect_description": "",
				"effect_factor": 0.0,
				"quality": 2,
				"price": 120
			},
			{
				"id": 13,
				"bag_slot_id": 2,
				"item_name": "Iron Chestplate",
				"type": "Chest",
				"subtype": "",
				"armor": 5,
				"strength": 2,
				"constitution": 3,
				"dexterity": -1,
				"luck": 0,
				"damage_min": 0,
				"damage_max": 0,
				"asset_id": 13,
				"effect_name": "",
				"effect_description": "",
				"effect_factor": 0.0,
				"quality": 2,
				"price": 200
			}
		],
		"perks": [
			{
				"perk_name": "Iron Will",
				"active": true,
				"description": "Resistance to debuffs",
				"asset_id": 7,
				"slot": 1,
				"effect1": "Constitution",
				"factor1": 4.0,
				"effect2": "",
				"factor2": 0.0
			},
			{
				"perk_name": "Heavy Hitter",
				"active": true,
				"description": "Increased damage with heavy weapons",
				"asset_id": 9,
				"slot": 2,
				"effect1": "Strength",
				"factor1": 5.0,
				"effect2": "",
				"factor2": 0.0
			}
		],
		"talents": [
			{
				"talent_id": 2,
				"points": 3
			},
			{
				"talent_id": 4,
				"points": 1
			}
		]
	},
	{
		"name": "Dark Assassin",
		"strength": 10,
		"constitution": 8,
		"dexterity": 20,
		"luck": 15,
		"armor": 2,
		"bag_slots": [
			{
				"id": 14,
				"bag_slot_id": 0,
				"item_name": "Poison Dagger",
				"type": "Weapon",
				"subtype": "Dagger",
				"armor": 0,
				"strength": 1,
				"constitution": 0,
				"dexterity": 4,
				"luck": 2,
				"damage_min": 3,
				"damage_max": 6,
				"asset_id": 14,
				"effect_name": "Poison",
				"effect_description": "Applies poison on hit",
				"effect_factor": 2.0,
				"quality": 3,
				"price": 300
			},
			{
				"id": 15,
				"bag_slot_id": 1,
				"item_name": "Leather Armor",
				"type": "Chest",
				"subtype": "",
				"armor": 2,
				"strength": 0,
				"constitution": 1,
				"dexterity": 3,
				"luck": 1,
				"damage_min": 0,
				"damage_max": 0,
				"asset_id": 15,
				"effect_name": "",
				"effect_description": "",
				"effect_factor": 0.0,
				"quality": 2,
				"price": 150
			}
		],
		"perks": [
			{
				"perk_name": "Shadow Strike",
				"active": true,
				"description": "Critical hits from stealth",
				"asset_id": 10,
				"slot": 1,
				"effect1": "Dexterity",
				"factor1": 6.0,
				"effect2": "Luck",
				"factor2": 4.0
			},
			{
				"perk_name": "Poison Master",
				"active": true,
				"description": "Enhanced poison effects",
				"asset_id": 11,
				"slot": 2,
				"effect1": "Dexterity",
				"factor1": 3.0,
				"effect2": "",
				"factor2": 0.0
			},
			{
				"perk_name": "Evasion",
				"active": false,
				"description": "Increased dodge chance",
				"asset_id": 12,
				"slot": 3,
				"effect1": "Dexterity",
				"factor1": 5.0,
				"effect2": "Luck",
				"factor2": 3.0
			}
		],
		"talents": [
			{
				"talent_id": 3,
				"points": 4
			},
			{
				"talent_id": 5,
				"points": 2
			},
			{
				"talent_id": 7,
				"points": 1
			}
		]
	}
]
