extends Node

func _ready():
	print("Websocket ready!")

# Mock data for development/testing
var mock_character_data = {
	"name": "TestPlayer",
	"gold": 1000,
	"currency": 50,
	"traveling": null,
	"traveling_destination": null,
	"location": "tavern",
	"strength": 15,
	"constitution": 12,
	"dexterity": 18,
	"luck": 10,
	"armor": 5,
	"talent_points": 10,
	"perk_points": 2,
	"dungeon": false,
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

# Mock NPC data with proper NpcInfo structure
var mock_npcs = [
	{
		"name": "Herald",
		"xpos": 0.2,
		"ypos": 0.3,
		"width": 1.0,
		"height": 1.0,
		"dialogue": "Welcome, brave adventurer! The kingdom needs your help! Welcome, brave adventurer! The kingdom needs your help!",
		"questid": null,
		"questname": null,
		"travel": null,
		"building": 0,
		"asset": "herald",
		"portrait": "npc_portrait",
		"traveltext": null
	},
	{
		"name": "Merchant Gareth",
		"xpos": 0.4,
		"ypos": 0.4,
		"width": 1.0,
		"height": 1.0,
		"dialogue": "Fine wares and rare items for sale! Come see what I have!",
		"questid": 1,
		"questname": "Delivery Quest",
		"travel": 5,
		"building": 0,
		"asset": "merchant",
		"portrait": "npc_portrait",
		"traveltext": "Travel to the next town"
	},
	{
		"name": "Guard Captain",
		"xpos": 0.6,
		"ypos": 0.25,
		"width": 1.2,
		"height": 1.1,
		"dialogue": "Stay vigilant, the kingdom is under threat from bandits.",
		"questid": 2,
		"questname": "Bandit Hunt",
		"travel": 10,
		"building": 0,
		"asset": "guard",
		"portrait": "npc_portrait",
		"traveltext": "Hunt down the bandits"
	},
	{
		"name": "Alchemist Zara",
		"xpos": 0.3,
		"ypos": 0.45,
		"width": 1.0,
		"height": 1.0,
		"dialogue": "Potions for sale! Healing, mana, and more!",
		"questid": null,
		"questname": null,
		"travel": null,
		"building": 0,
		"asset": "alchemist",
		"portrait": "npc_portrait",
		"traveltext": null
	},
	{
		"name": "Innkeeper Molly",
		"xpos": 0.25,
		"ypos": 0.55,
		"width": 1.0,
		"height": 1.0,
		"dialogue": "Rooms available for rent! Come rest your weary heads.",
		"questid": null,
		"questname": null,
		"travel": null,
		"building": 0,
		"asset": "innkeeper",
		"portrait": "npc_portrait",
		"traveltext": null
	},
	{
		"name": "Blacksmith Jane",
		"xpos": 0.5,
		"ypos": 0,
		"width": 4.0,
		"height": 4.0,
		"dialogue": "Weapons and armor repaired! Come see me at the forge.",
		"questid": 3,
		"questname": "Metal Collection",
		"travel": 8,
		"building": 1,
		"asset": "blacksmith",
		"portrait": "npc_portrait",
		"traveltext": "Gather rare metals"
	}
]

# Mock chat data
var mock_chat_messages = [
	{
		"sender": "Herald",
		"timestamp": "2025-08-08T10:30:00Z",
		"status": "lord",
		"message": "Welcome, brave adventurers! The tournament begins at dawn!",
		"type": "global"
	},
	{
		"sender": "Farmer Joe",
		"timestamp": "2025-08-08T10:31:15Z", 
		"status": "peasant",
		"message": "Anyone know where I can buy better seeds? My crops aren't growing well.",
		"type": "local"
	},
	{
		"sender": "Lady Ashford",
		"timestamp": "2025-08-08T10:32:30Z",
		"status": "lord", 
		"message": "The Royal Treasury is offering bounties for rare artifacts.",
		"type": "global"
	},
	{
		"sender": "Blacksmith Tom",
		"timestamp": "2025-08-08T10:33:45Z",
		"status": "peasant",
		"message": "Need iron ore! Will trade weapons for quality materials.",
		"type": "local"
	},
	{
		"sender": "Sir Gareth",
		"timestamp": "2025-08-08T10:35:00Z",
		"status": "lord",
		"message": "Beware the dark forest - strange creatures have been spotted there.",
		"type": "global"
	},
	{
		"sender": "Merchant Mills",
		"timestamp": "2025-08-08T10:36:20Z",
		"status": "peasant",
		"message": "Fresh potions and supplies at the market square!",
		"type": "local"
	},
	{
		"sender": "Captain Reynolds",
		"timestamp": "2025-08-08T10:37:45Z",
		"status": "lord",
		"message": "Guards are needed at the city gates. Report to the barracks.",
		"type": "global"
	},
	{
		"sender": "Young Tim",
		"timestamp": "2025-08-08T10:39:10Z",
		"status": "peasant",
		"message": "Has anyone seen my lost cat? It's orange with white paws.",
		"type": "local"
	},
	{
		"sender": "Duchess Elena",
		"timestamp": "2025-08-08T10:40:30Z",
		"status": "lord",
		"message": "The grand ball is this weekend. All nobles are invited.",
		"type": "global"
	},
	{
		"sender": "Baker Bill",
		"timestamp": "2025-08-08T10:41:50Z",
		"status": "peasant",
		"message": "Fresh bread and pastries! Hot from the oven!",
		"type": "local"
	},
	{
		"sender": "Wizard Eldrin",
		"timestamp": "2025-08-08T10:43:15Z",
		"status": "lord",
		"message": "I seek apprentices to help with my research. Interested parties, come see me.",
		"type": "global"
	},
	{
		"sender": "Guard Captain",
		"timestamp": "2025-08-08T10:44:40Z",
		"status": "lord",
		"message": "Stay vigilant, the kingdom is under threat from bandits.",
		"type": "global"
	},
	{
		"sender": "Alchemist Zara",
		"timestamp": "2025-08-08T10:46:05Z",
		"status": "peasant",
		"message": "Potions for sale! Healing, mana, and more!",
		"type": "local"
	},
	{
		"sender": "Knight Commander",
		"timestamp": "2025-08-08T10:57:30Z",
		"status": "lord",
		"message": "All knights must report for training at the castle courtyard.",
		"type": "global"
	},
	{
		"sender": "Innkeeper Molly",
		"timestamp": "2025-08-08T10:58:45Z",
		"status": "peasant",
		"message": "Rooms available for rent! Come rest your weary heads.",
		"type": "local"
	},
	{
		"sender": "Bard Lyra",
		"timestamp": "2025-08-08T10:59:50Z",
		"status": "peasant",
		"message": "Hear ye, hear ye! Tales of adventure and glory await!",
		"type": "local"
	},
	{
		"sender": "Mayor Thompson",
		"timestamp": "2025-08-08T10:59:15Z",
		"status": "lord",
		"message": "The town council meets every Friday. All are welcome to attend.",
		"type": "global"
	},
	{
		"sender": "Hunter Greg",
		"timestamp": "2025-08-08T10:59:40Z",
		"status": "peasant",
		"message": "Looking for hunting partners. Plenty of game in the hills.",
		"type": "local"
	},
	{
		"sender": "Priestess Mira",
		"timestamp": "2025-08-08T10:59:05Z",
		"status": "lord",
		"message": "The temple is open for prayers and blessings. All are welcome.",
		"type": "global"
	},
	{
		"sender": "Farmer Ann",
		"timestamp": "2025-08-08T10:59:30Z",
		"status": "peasant",
		"message": "Need help harvesting crops! Good food in return.",
		"type": "local"
	},
	{
		"sender": "Blacksmith Jane",
		"timestamp": "2025-08-08T10:59:55Z",
		"status": "peasant",
		"message": "Weapons and armor repaired! Come see me at the forge.",
		"type": "local"
	},
	{
		"sender": "Ada Jane",
		"timestamp": "2025-08-08T10:59:55Z",
		"status": "peasant",
		"message": "asdasasd asdasda",
		"type": "local"
	},
	{
		"sender": "Ada Jane",
		"timestamp": "2025-08-08T10:59:55Z",
		"status": "peasant",
		"message": "adadadadsss asdasda",
		"type": "local"
	},
	{
		"sender": "Ada Jane",
		"timestamp": "2025-08-08T10:59:55Z",
		"status": "peasant",
		"message": "asdadsssss asdasda",
		"type": "local"
	},
	{
		"sender": "Ada Jane",
		"timestamp": "2025-08-08T10:59:55Z",
		"status": "peasant",
		"message": "asdadsssss asdasda",
		"type": "local"
	},
	{
		"sender": "Ada Jane",
		"timestamp": "2025-08-08T10:59:55Z",
		"status": "peasant",
		"message": "penus",
		"type": "local"
	},

]

# Mock combat data for development/testing
var mock_combat_logs = [
	{
		"player1name": "Sir Galahad",
		"player1health": 100,
		"player2name": "Dark Knight",
		"player2health": 120,
		"final_message": "Sir Galahad emerges victorious!",
		"logs": [
			{
				"turn": 1,
				"player": "Sir Galahad",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 1,
				"player": "Dark Knight",
				"action": "hit",
				"factor": 15
			},
			{
				"turn": 2,
				"player": "Dark Knight",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 2,
				"player": "Sir Galahad",
				"action": "dodge",
				"factor": 0
			},
			{
				"turn": 3,
				"player": "Sir Galahad",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 3,
				"player": "Dark Knight",
				"action": "hit",
				"factor": 22
			},
			{
				"turn": 4,
				"player": "Dark Knight",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 4,
				"player": "Sir Galahad",
				"action": "hit",
				"factor": 18
			},
			{
				"turn": 5,
				"player": "Sir Galahad",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 5,
				"player": "Dark Knight",
				"action": "hit",
				"factor": 25
			},
			{
				"turn": 6,
				"player": "Dark Knight",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 6,
				"player": "Sir Galahad",
				"action": "hit",
				"factor": 12
			},
			{
				"turn": 7,
				"player": "Sir Galahad",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 7,
				"player": "Dark Knight",
				"action": "hit",
				"factor": 28
			}
		]
	},
	{
		"player1name": "You",
		"player1health": 85,
		"player2name": "Goblin Warrior",
		"player2health": 60,
		"final_message": "Victory! You gain experience and gold.",
		"logs": [
			{
				"turn": 1,
				"player": "You",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 1,
				"player": "Goblin Warrior",
				"action": "hit",
				"factor": 12
			},
			{
				"turn": 2,
				"player": "Goblin Warrior",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 2,
				"player": "You",
				"action": "dodge",
				"factor": 0
			},
			{
				"turn": 3,
				"player": "You",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 3,
				"player": "Goblin Warrior",
				"action": "hit",
				"factor": 18
			},
			{
				"turn": 4,
				"player": "Goblin Warrior",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 4,
				"player": "You",
				"action": "hit",
				"factor": 8
			},
			{
				"turn": 5,
				"player": "You",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 5,
				"player": "Goblin Warrior",
				"action": "hit",
				"factor": 20
			},
			{
				"turn": 6,
				"player": "Goblin Warrior",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 6,
				"player": "You",
				"action": "miss",
				"factor": 0
			},
			{
				"turn": 7,
				"player": "You",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 7,
				"player": "Goblin Warrior",
				"action": "hit",
				"factor": 22
			}
		]
	},
	{
		"player1name": "Wizard Eldara",
		"player1health": 80,
		"player2name": "Fire Demon",
		"player2health": 150,
		"final_message": "The Fire Demon is defeated by magical prowess! and suffers a humiliating defeat. anyways we should have a celebration, invite the wenches and lets drink to our victory!",
		"logs": [
			{
				"turn": 1,
				"player": "Wizard Eldara",
				"action": "cast spell",
				"factor": 0
			},
			{
				"turn": 1,
				"player": "Fire Demon",
				"action": "hit",
				"factor": 30
			},
			{
				"turn": 1,
				"player": "Wizard Eldara",
				"action": "burn damage",
				"factor": 5
			},
			{
				"turn": 2,
				"player": "Fire Demon",
				"action": "rage",
				"factor": 0
			},
			{
				"turn": 2,
				"player": "Fire Demon",
				"action": "fire breath",
				"factor": 0
			},
			{
				"turn": 2,
				"player": "Fire Demon",
				"action": "intimidate",
				"factor": 0
			},
			{
				"turn": 2,
				"player": "Wizard Eldara",
				"action": "hit",
				"factor": 25
			},
			{
				"turn": 3,
				"player": "Wizard Eldara",
				"action": "heal",
				"factor": 15
			},
			{
				"turn": 3,
				"player": "Wizard Eldara",
				"action": "shield",
				"factor": 0
			},
			{
				"turn": 3,
				"player": "Fire Demon",
				"action": "attack",
				"factor": 0
			},
			{
				"turn": 4,
				"player": "Fire Demon",
				"action": "claw strike",
				"factor": 0
			},
			{
				"turn": 4,
				"player": "Wizard Eldara",
				"action": "hit",
				"factor": 12
			}
		]
	}
]
