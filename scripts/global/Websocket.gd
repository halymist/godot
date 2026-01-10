extends Node

# Helper function to generate full player data
func generate_mock_player_data(player_name: String, rank: int, faction: int, profession: int, honor: int) -> Dictionary:
	# Generate varied stats based on rank (better players have higher stats)
	var stat_bonus = max(0, (100 - rank) / 10)  # Top 10 get +9, rank 100 gets 0
	
	return {
		"name": player_name,
		"rank": rank,
		"faction": faction,
		"profession": profession,
		"honor": honor,
		"avatar_face": 1,  # Cosmetic ID from database
		"avatar_hair": 10 if (rank % 2) == 0 else 11,  # Alternate between hair styles (IDs 10 and 11)
		"avatar_eyes": 20,  # Cosmetic ID from database
		"avatar_nose": 30,  # Cosmetic ID from database
		"avatar_mouth": 40,  # Cosmetic ID from database
		"strength": 10 + stat_bonus + (rank % 5),
		"stamina": 10 + stat_bonus + (rank % 4),
		"agility": 10 + stat_bonus + (rank % 6),
		"luck": 8 + (rank % 8),
		"armor": 5 + (stat_bonus / 2),
		"blessing": 50 + (rank % 100),
		"potion": 400,
		"elixir": 0,
		"bag_slots": [
			{"id": 1, "bag_slot_id": 0},  # Basic helmet
			{"id": 2, "bag_slot_id": 2} if rank <= 50 else {}  # Better players have chest armor
		],
		"perks": [
			{"id": 1, "active": true, "slot": 1} if rank <= 70 else {"id": 2, "active": true, "slot": 1}
		],
		"talents": [
			{"talent_id": 1, "points": min(5, (100 - rank) / 20 + 1)},
			{"talent_id": 2, "points": min(3, (100 - rank) / 30)} if rank <= 60 else {}
		]
	}

func _ready():
	print("Websocket ready!")
	
	# Generate rankings for each character
	for character in mock_characters:
		for i in range(1, 101):
			character.rankings.append(generate_mock_player_data(
				"Player" + str(i),
				i,  # rank
				(i % 3) + 1,  # faction
				(i % 3) + 1,  # profession
				10000 - (i * 50)  # honor
			))


# Mock characters array - each character has their own world/data
var mock_characters = [
	{
	"name": "TestPlayer",
	"faction": 1,
	"rank": 15486,
	"profession": 1,
	"server_timezone": "Europe/Stockholm",
	"server_day": 50,
	"weather": 2,  # 1=sunny, 2=rainy
	"daily_quests": [1, 2, 3],
	"avatar_face": 1,  # Cosmetic ID from database
	"avatar_hair": 10,  # Cosmetic ID from database
	"avatar_eyes": 20,  # Cosmetic ID from database
	"avatar_nose": 30,  # Cosmetic ID from database
	"avatar_mouth": 40,  # Cosmetic ID from database
	"quest_log": [		
	],
	"silver": 1000,
	"mushrooms": 150,
	"vip": false,
	"autoskip": false,
	"traveling": null,
	"traveling_destination": null,
	"location": 1,
	"strength": 10,
	"stamina": 12,
	"agility": 18,
	"luck": 10,
	"armor": 5,
	"talent_points": 10,
	"blessing": 100,
	"potion": 0,
	"elixir": 0,
	"dungeon": false,
	"slide": 1,
	"slides": null,
	"bag_slots": [
		{
			"id": 1,
			"effect_overdrive": 4,
			"bag_slot_id": 0,
			"day": 40
		},
		{
			"id": 2,
			"bag_slot_id": 5,
			"day": 40
		},
		{
			"id": 5,
			"bag_slot_id": 8,
			"day": 40
		},
		{
			"id": 401,
			"bag_slot_id": 10,
		},
		{
			"id": 400,
			"bag_slot_id": 11,
			"day": 5
		},
		{
			"id": 500,
			"bag_slot_id": 12,
			"day": 2
		},
		{
			"id": 390,
			"bag_slot_id": 13,
			"day": 40
		}
	],
	"perks": [
		{
			"id": 1,
			"active": false,
			"slot": 1
		},
		{
			"id": 2,
			"active": false,
			"slot": 2
		},
		{
			"id": 3,
			"active": false,
			"slot": 3
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
		],
		"arena_opponents": ["Player5", "Player12", "Player25"],  # References to enemy_players by name
		"vendor_items": [1, 1, 1, 1, 1, 1, 1, 1],  # Items available for purchase
		"enchanter_effects": [4, 5, 6, 7],  # Effect IDs available for enchanting
		"rankings": [],  # Will be populated in _ready()
		"chat_messages": [
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
			}
		]
	}
]

# NPCs are now client-side resources - server only sends daily_quests array in character data

# Mock combat data for development/testing (separate from character data)
var mock_combat_logs = [
	{
		"player1name": "TestPlayer",
		"player1health": 100,
		"player1_avatar": [1, 10, 20, 30, 40],
		"player2name": "Dark Knight",
		"player2health": 120,
		"player2_avatar": [1, 11, 20, 30, 40],
		"haswon": false,
		"logs": [
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 15},
			{"player": 2, "action": "attack", "factor": 0},
			{"player": 1, "action": "dodge", "factor": 0},
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 22},
			{"player": 2, "action": "attack", "factor": 0},
			{"player": 1, "action": "hit", "factor": 18},
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 25},
			{"player": 2, "action": "attack", "factor": 0},
			{"player": 1, "action": "hit", "factor": 12},
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 28}
		]
	},
	{
		"player1name": "TestPlayer",
		"player1health": 85,
		"player1_avatar": [1, 10, 20, 30, 40],
		"enemyid": 1,
		"player2health": 60,
		"haswon": true,
		"logs": [
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 12},
			{"player": 2, "action": "attack", "factor": 0},
			{"player": 1, "action": "dodge", "factor": 0},
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 18},
			{"player": 2, "action": "attack", "factor": 0},
			{"player": 1, "action": "hit", "factor": 8},
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 20},
			{"player": 2, "action": "attack", "factor": 0},
			{"player": 1, "action": "miss", "factor": 0},
			{"player": 1, "action": "attack", "factor": 0},
			{"player": 2, "action": "hit", "factor": 22}
		]
	},
	{
		"player1name": "TestPlayer",
		"player1health": 80,
		"player1_avatar": [1, 10, 20, 30, 40],
		"enemyid": 3,
		"player2health": 150,
		"haswon": true,
		"logs": [
			{"player": 1, "action": "cast spell", "factor": 0},
			{"player": 2, "action": "hit", "factor": 30},
			{"player": 1, "action": "burn damage", "factor": 5},
			{"player": 2, "action": "rage", "factor": 0},
			{"player": 2, "action": "fire breath", "factor": 0},
			{"player": 2, "action": "intimidate", "factor": 0},
			{"player": 1, "action": "hit", "factor": 25},
			{"player": 1, "action": "heal", "factor": 15},
			{"player": 1, "action": "shield", "factor": 0},
			{"player": 2, "action": "attack", "factor": 0},
			{"player": 2, "action": "claw strike", "factor": 0},
			{"player": 1, "action": "hit", "factor": 12}
		]
	}
]
