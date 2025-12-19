extends Node

func _ready():
	print("Websocket ready!")
	
	# Generate 100 mock ranking entries
	for i in range(1, 101):
		mock_rankings.append({
			"name": "Player" + str(i),
			"rank": i,
			"guild": (i % 3) + 1,  # Distribute across 3 guilds
			"profession": (i % 3) + 1,  # 3 professions
			"honor": 10000 - (i * 50)  # Higher rank = higher honor
		})

# Mock quest log data - tracks quest completion status
var mock_quest_log = [
	# Example: {"quest_id": 1, "slides": [1, 2, 4], "finished": true}
	# Empty array means no quests completed yet
]

# Mock rankings data (lightweight - sent on rankings panel open)
var mock_rankings = []

# Mock data for development/testing
var mock_character_data = {
	"name": "TestPlayer",
	"guild": 1,
	"rank": 15486,
	"profession": 1,
	"server_timezone": "Europe/Stockholm",
	"weather": 2,  # 1=sunny, 2=rainy
	"daily_quests": [1, 2, 3],
	"avatar_face": 1,
	"avatar_hair": 1,
	"avatar_eyes": 1,
	"quest_log": [
		{"quest_id": 1, "slides": [1], "finished": false},
		{"quest_id": 2, "slides": [1, 2], "finished": false}
	],
	"gold": 1000,
	"mushrooms": 150,
	"traveling": null,
	"traveling_destination": null,
	"location": 1,
	"strength": 15,
	"stamina": 12,
	"agility": 18,
	"luck": 10,
	"armor": 5,
	"talent_points": 10,
	"perk_points": 2,
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
			"bag_slot_id": 11,
			"day": 3
		},
		{
			"id": 400,
			"bag_slot_id": 12,
			"day": 5
		},
		{
			"id": 500,
			"bag_slot_id": 13,
			"day": 2
		},
		{
			"id": 390,
			"bag_slot_id": 14,
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
	]
}

# Mock arena opponents data
var mock_arena_opponents = [
	{
		"name": "Goblin Warrior",
		"rank": 8500,
		"strength": 12,
		"stamina": 10,
		"agility": 14,
		"luck": 8,
		"armor": 3,
		"bag_slots": [
			{
				"id": 1,
				"bag_slot_id": 0
			}
		],
		"perks": [
			{
				"id": 1,
				"active": true,
				"slot": 1
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
		"rank": 12000,
		"strength": 18,
		"stamina": 16,
		"agility": 8,
		"luck": 6,
		"armor": 8,
		"bag_slots": [
			{
				"id": 1,
				"bag_slot_id": 0
			},
			{
				"id": 1,
				"bag_slot_id": 2
			}
		],
		"perks": [
			{
				"id": 1,
				"active": true,
				"slot": 1
			},
			{
				"id": 1,
				"active": true,
				"slot": 2
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
		"rank": 18500,
		"strength": 10,
		"stamina": 8,
		"agility": 20,
		"luck": 15,
		"armor": 2,
		"bag_slots": [
			{
				"id": 1,
				"bag_slot_id": 0
			},
			{
				"id": 1,
				"bag_slot_id": 1
			}
		],
		"perks": [
			{
				"id": 1,
				"active": true,
				"slot": 1
			},
			{
				"id": 1,
				"active": true,
				"slot": 2
			},
			{
				"id": 1,
				"active": false,
				"slot": 3
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

# NPCs are now client-side resources - server only sends daily_quests array in character data

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

# Mock quest data organized by questID
var mock_quests = {
	1: {  # Merchant Gareth's delivery quest
		"quest_id": 1,
		"quest_name": "Delivery Quest",
		"travel_time": 5,  # minutes
		"travel_text": "Travel to the next town",
		"slides": [
			{
				"slide": 1,
				"assetID": 1,
				"text": "As you walk along the dusty road leading away from the village, you notice a figure slumped against a weathered milestone. Drawing closer, you see it's a traveler - their clothes torn and dirtied, their pack lying open beside them with its contents scattered across the ground. They look up at you with desperate eyes, clearly distressed by whatever misfortune has befallen them on this lonely stretch of road.",
				"options": [
					{
						"optionIndex": 1,
						"type": "dialogue",
						"text": "Ask what's wrong",
						"slideTarget": 2
					},
					{
						"optionIndex": 2,
						"type": "dialogue", 
						"text": "Ignore them and continue",
						"slideTarget": 3
					}
				],
				"reward": null
			},
			{
				"slide": 2,
				"assetID": 1,
				"text": "The traveler's words tumble out in a rush of panic and frustration. They explain that just an hour ago, a group of bandits emerged from the forest and attacked them without warning. The brigands took everything of value - their coin purse, their supplies, and most importantly, a precious family heirloom they were transporting to the next town. The traveler clutches your sleeve desperately, begging you to help retrieve their stolen belongings before the bandits disappear into the wilderness forever.",
				"options": [
					{
						"optionIndex": 1,
						"type": "combat",
						"text": "Agree to help fight the bandits",
						"enemy": 1,
						"onWinSlide": 4,
						"onLooseSlide": 5
					},
					{
						"optionIndex": 2,
						"type": "dialogue",
						"text": "Apologize but decline to help",
						"slideTarget": 3
					}
				],
				"reward": null
			},
			{
				"slide": 3,
				"assetID": 1,
				"text": "You offer the traveler some words of sympathy, but ultimately decide that their troubles are not your concern. The traveler's face falls as they realize you won't be helping them, and they turn away in disappointment. You continue down the road, leaving them behind to figure out their own solution. The encounter weighs on your mind as you walk, but you push the thoughts aside and focus on your own journey ahead.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "End quest",
						"slideTarget": -1
					}
				],
				"reward": null
			},
			{
				"slide": 4,
				"assetID": 1,
				"text": "After a fierce battle, you stand victorious over the defeated bandits! You retrieve the stolen goods and return them to the grateful traveler. Their eyes light up with joy and relief as they verify that everything is there, especially the precious heirloom. As a token of their gratitude, they press a heavy pouch of gold coins into your hands, insisting you take it as a reward for your bravery. They thank you profusely before continuing on their way, their faith in humanity restored.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "Accept reward and end quest",
						"slideTarget": -1
					}
				],
				"reward": {
					"gold": 100,
					"experience": 50
				}
			},
			{
				"slide": 5,
				"assetID": 1,
				"text": "The bandits prove to be more skilled and ruthless than you anticipated. Despite your best efforts, they overwhelm you with their superior numbers and brutal fighting tactics. You're forced to retreat, nursing your wounds and cursing your misfortune. The traveler watches sadly as you limp away, their hope of recovering their belongings fading with your departure. You live to fight another day, but the sting of defeat lingers.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "End quest",
						"slideTarget": -1
					}
				],
				"reward": null
			}
		]
	},
	2: {  # Guard Captain's bandit hunt
		"quest_id": 2,
		"quest_name": "Bandit Hunt",
		"travel_time": 10,  # minutes
		"travel_text": "Hunt down the bandits",
		"slides": [
			{
				"slide": 1,
				"assetID": 2,
				"text": "The Guard Captain's stern face reflects the gravity of the situation as he unfolds a worn map across the wooden table. He points to several marked locations where bandit attacks have occurred over the past few weeks. The raids have grown bolder and more frequent, threatening the safety of merchants and travelers on the main roads. He explains that the town guard is stretched thin protecting the walls and cannot spare enough men for a proper hunt. That's where you come in - he needs someone skilled and brave enough to track down these criminals and put an end to their reign of terror before they strike again. BLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASL BLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASLBLA BLAB ALBLSFJDSKSFJASL",
				"options": [
					{
						"optionIndex": 1,
						"type": "dialogue",
						"text": "Accept the mission",
						"slideTarget": 2
					},
					{
						"optionIndex": 2,
						"type": "dialogue",
						"text": "Decline the mission",
						"slideTarget": 3
					}
				],
				"reward": null
			},
			{
				"slide": 2,
				"assetID": 2,
				"text": "Following the trail of disturbed earth and broken branches, you navigate through dense woodland until you discover the bandits' hidden camp nestled in a rocky ravine. Smoke rises from their campfire, and you can hear their rough voices carrying through the trees as they divide their latest plunder. The element of surprise is on your side - they don't expect anyone to have tracked them this deep into the wilderness. You count at least five figures moving around the camp, armed and dangerous. This is your chance to end their criminal enterprise once and for all.",
				"options": [
					{
						"optionIndex": 1,
						"type": "combat",
						"text": "Attack the bandits",
						"enemy": 2,
						"onWinSlide": 4,
						"onLooseSlide": 5
					}
				],
				"reward": null
			},
			{
				"slide": 3,
				"assetID": 2,
				"text": "You respectfully decline the Guard Captain's request, explaining that you have other pressing matters to attend to. The captain's expression hardens with disappointment, but he nods curtly in understanding. He warns you that if the bandit problem continues to escalate, it will eventually affect everyone in the region, including you. As you leave his office, you can't help but wonder if you made the right choice. The town will have to find another solution to their bandit problem.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "End quest",
						"slideTarget": -1
					}
				],
				"reward": null
			},
			{
				"slide": 4,
				"assetID": 2,
				"text": "Victory is yours! The bandit camp lies in ruins, their weapons scattered and their leader defeated. You've successfully eliminated the threat that has plagued these roads for weeks. As you make your way back to town with evidence of your success, word of your deed spreads quickly. The Guard Captain greets you personally at the gate, relief and gratitude evident on his weathered face. He presents you with a substantial reward from the town's coffers, along with the thanks of every merchant and traveler who can now pass safely through these lands.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "Collect reward",
						"slideTarget": -1
					}
				],
				"reward": {
					"gold": 200,
					"experience": 100
				}
			},
			{
				"slide": 5,
				"assetID": 2,
				"text": "The battle turns against you as the bandits prove to be more organized and skilled than you anticipated. Their leader barks orders with military precision, coordinating their attacks to overwhelm you. Wounded and outmatched, you're forced to retreat back into the forest, using the dense undergrowth to cover your escape. The bandits' mocking laughter echoes behind you as you flee. You'll need to regroup, tend to your wounds, and perhaps gather allies before attempting to face them again. This fight is far from over.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "End quest",
						"slideTarget": -1
					}
				],
				"reward": null
			}
		]
	},
	3: {  # Blacksmith Jane's metal collection
		"quest_id": 3,
		"quest_name": "Metal Collection",
		"travel_time": 8,  # minutes
		"travel_text": "Gather rare metals",
		"slides": [
			{
				"slide": 1,
				"assetID": 3,
				"text": "The blacksmith's forge glows hot as she hammers away at a piece of steel, sparks flying with each strike. When she notices you, she sets down her hammer and wipes the sweat from her brow. She explains that she's received a commission for a very important order - armor for a noble's personal guard - but she's run critically low on the specific rare metals required for the job. The veins near town have been depleted, but she's heard rumors of rich deposits deep within the old abandoned mines to the north. However, those mines were sealed years ago for a reason - dangerous creatures have made their home in the dark tunnels. She needs someone brave enough to venture inside and retrieve the precious metals.",
				"options": [
					{
						"optionIndex": 1,
						"type": "dialogue",
						"text": "Agree to help gather metals",
						"slideTarget": 2
					},
					{
						"optionIndex": 2,
						"type": "dialogue",
						"text": "Not interested",
						"slideTarget": 3
					}
				],
				"reward": null
			},
			{
				"slide": 2,
				"assetID": 3,
				"text": "The entrance to the abandoned mine yawns before you like a dark, foreboding mouth. The air that drifts out is cold and damp, carrying with it strange echoing sounds from deep within. Your torch casts dancing shadows on the rough stone walls as you descend into the depths, following the glimmer of metallic veins running through the rock. The deeper you go, the more evident it becomes that you're not alone - claw marks score the walls, and bones of unfortunate creatures litter the ground. Suddenly, glowing eyes appear in the darkness ahead, and the sound of chittering grows louder. The mine's monstrous inhabitants have discovered your presence.",
				"options": [
					{
						"optionIndex": 1,
						"type": "combat",
						"text": "Mine the metals (face cave monsters)",
						"enemy": 3,
						"onWinSlide": 4,
						"onLooseSlide": 5
					}
				],
				"reward": null
			},
			{
				"slide": 3,
				"assetID": 3,
				"text": "You politely decline the blacksmith's request, citing the extreme danger involved in venturing into monster-infested mines. She looks disappointed but understanding, mentioning that she'll have to find another solution - perhaps hiring a more experienced mining crew or sourcing the metals from distant traders at a premium price. As you leave the forge, you can hear her muttering calculations about how much the delay will cost her commission. The sound of her hammer resumes its rhythmic beat against the anvil.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "End quest",
						"slideTarget": -1
					}
				],
				"reward": null
			},
			{
				"slide": 4,
				"assetID": 3,
				"text": "After a harrowing battle with the cave dwellers, you emerge from the mines victorious, your pack heavy with chunks of the rare metals the blacksmith needs. The sunlight has never felt so welcoming after the oppressive darkness below. When you return to the forge and present your findings, the blacksmith's eyes light up with professional excitement. She examines each piece carefully, nodding with satisfaction at the quality and quantity you've retrieved. This is exactly what she needed! She insists on paying you handsomely for your courage and effort, plus promises you a discount on any future work you might need done.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "Collect payment",
						"slideTarget": -1
					}
				],
				"reward": {
					"gold": 150,
					"experience": 75
				}
			},
			{
				"slide": 5,
				"assetID": 3,
				"text": "The cave monsters prove to be too numerous and aggressive, their chittering cries echoing through the tunnels as they swarm from every dark corner. You manage to grab a few small pieces of metal, but the relentless attacks force you to abandon the mission and flee back toward the entrance. Your torch sputters and nearly goes out as you sprint through the darkness, the sounds of pursuit gradually fading behind you. You emerge from the mine empty-handed and exhausted, the small samples you managed to collect insufficient for the blacksmith's needs. You'll have to report your failure.",
				"options": [
					{
						"optionIndex": 1,
						"type": "end",
						"text": "End quest",
						"slideTarget": -1
					}
				],
				"reward": null
			}
		]
	}
}

# Legacy mock_quest_slides for backward compatibility (removed in favor of mock_quests)
var mock_quest_slides = []

# Mock enchanter effects data - array of effect IDs (factors are stored in effects.tres)
var mock_enchanter_effects = [4, 5, 6, 7]  # Effect IDs available for enchanting

# Mock vendor items data - items available for purchase (order doesn't matter)
var mock_vendor_items = [1, 1, 1, 1, 1, 1, 1, 1]
