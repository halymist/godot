extends Node

# ============================================
# WEBSOCKET AUTOLOAD
# ============================================
# Handles all in-game WebSocket communication with the server

# WebSocket connection
var ws: WebSocketPeer
var ws_url: String = "ws://localhost:3000"
var connected: bool = false

# Signals
signal player_data_received(character_data: Dictionary)


# Helper function to generate full player data
func generate_mock_player_data(player_name: String, rank: int, faction: int, honor: int, char_id: int = 0) -> Dictionary:
	# Generate varied stats based on rank (better players have higher stats)
	var stat_bonus = max(0, (100 - rank) / 10)  # Top 10 get +9, rank 100 gets 0
	
	return {
		"character_id": char_id if char_id > 0 else rank,
		"name": player_name,
		"rank": rank,
		"faction": faction,
		"honor": honor,
		"avatar": [1, 10 if (rank % 2) == 0 else 11, 20, 30, 40],  # [face, hair, eyes, nose, mouth]
		"stats": [
			10 + stat_bonus + (rank % 5),  # strength
			10 + stat_bonus + (rank % 4),  # stamina
			10 + stat_bonus + (rank % 6),  # agility
			8 + (rank % 8),  # luck
			5 + (stat_bonus / 2),  # armor
			5 + (rank % 3),  # damage_min
			10 + (rank % 5)  # damage_max
		],
		"blessing": 0,  # No blessing by default (only IDs 1-4 exist in perks.tres)
		"potion": 0,  # No potion by default
		"elixir": [],  # Array of ingredient IDs (empty = no elixir)
		"bag_slots": [
			{"id": 1, "bag_slot_id": 0, "day": 30 + stat_bonus},  # Basic helmet with day scaling
			{"id": 2, "bag_slot_id": 2, "day": 25 + stat_bonus} if rank <= 50 else {}  
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
	set_process(false)  # Only process when connected
	
	# Note: Rankings are now loaded from server in playerData response
	# No need to generate mock rankings anymore

func _process(_delta):
	"""Poll WebSocket for new messages"""
	if not ws:
		return
	
	ws.poll()
	var state = ws.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var packet = ws.get_packet()
			var message = packet.get_string_from_utf8()
			_handle_message(message)
	elif state == WebSocketPeer.STATE_CLOSING:
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		var code = ws.get_close_code()
		var reason = ws.get_close_reason()
		print("[WebSocket] Closed with code: %d, reason: %s" % [code, reason])
		connected = false
		set_process(false)

func connect_to_server():
	"""Connect to WebSocket server"""
	ws = WebSocketPeer.new()
	var err = ws.connect_to_url(ws_url)
	
	if err != OK:
		print("[WebSocket] Failed to connect: ", err)
		return false
	
	print("[WebSocket] Connecting to ", ws_url)
	set_process(true)
	
	# Wait for connection
	var max_attempts = 50  # 5 seconds
	for i in range(max_attempts):
		ws.poll()
		var state = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			connected = true
			print("[WebSocket] Connected!")
			return true
		elif state == WebSocketPeer.STATE_CLOSED:
			print("[WebSocket] Connection failed")
			return false
		await get_tree().create_timer(0.1).timeout
	
	print("[WebSocket] Connection timeout")
	return false

func disconnect_from_server():
	"""Disconnect from WebSocket server"""
	if ws:
		ws.close()
		ws = null
		connected = false
		set_process(false)
		print("[WebSocket] Disconnected")

func join_lobby(server_id: int, character_id: int, token: String):
	"""Send joinLobby message to server"""
	if not connected:
		print("[WebSocket] Not connected! Cannot send joinLobby")
		return
	
	var payload = {
		"character_id": character_id,
		"token": token
	}
	
	var message = {
		"function": "joinLobby",
		"int_argument1": server_id,
		"string_argument": JSON.stringify(payload)
	}
	
	var json = JSON.stringify(message)
	print("[WebSocket] Sending joinLobby: ", json)
	ws.send_text(json)

func _handle_message(message: String):
	"""Handle incoming WebSocket messages"""
	print("[WebSocket] Received: ", message)
	
	var json = JSON.new()
	var error = json.parse(message)
	
	if error != OK:
		print("[WebSocket] Failed to parse JSON: ", json.get_error_message())
		return
	
	var data = json.get_data()
	
	if typeof(data) != TYPE_DICTIONARY:
		print("[WebSocket] Invalid message format")
		return
	
	var function_name = data.get("function", "")
	
	match function_name:
		"playerData":
			_handle_player_data(data)
		_:
			print("[WebSocket] Unknown function: ", function_name)

func _handle_player_data(message: Dictionary):
	"""Handle playerData response"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid playerData format")
		return
	
	var character_data = message.data[0]
	print("[WebSocket] Player data received for character: ", character_data.get("character_id", "unknown"))
	
	# Emit signal with character data
	player_data_received.emit(character_data)


# Mock characters array - each character has their own world/data
var mock_characters = [
	{
	# Server info
	"server_timezone": "Europe/Stockholm",
	"server_day": 50,
	"weather": 2,  # 1=sunny, 2=rainy
	"location": 1,
	
	# Character info
	"character_id": 10078,
	"name": "TestPlayer",
	"faction": 1,
	"rank": 78,
	"honor": 6120,
	"avatar": [1, 10, 20, 30, 40],  # [face, hair, eyes, nose, mouth]
	"stats": [10, 12, 18, 10, 5, 5, 12],  # [strength, stamina, agility, luck, armor, damage_min, damage_max]
	"silver": 700,
	"talent_points": 10,
	"blessing": 100,
	"potion": 0,
	"elixir": [],  # Array of ingredient IDs when active, empty when none
	
	# Flags and state
	"vip": false,
	"traveling": null,
	"traveling_destination": null,
	"dungeon": false,
	"daily_quests": [1, 2, 3],
	"quest_log": [],
	"expedition": [],  # Array: [current_slide] when active, empty when not on expedition
	"bag_slots": [
		{
			"id": 1,
			"effect_overdrive": 4,
			"bag_slot_id": 0,
			"day": 40,
			"socket_id": 390,
			"socket_day": 20
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
			"id": 373,
			"bag_slot_id": 11
		},
		{
			"id": 500,
			"bag_slot_id": 12
		},
		{
			"id": 500,
			"bag_slot_id": 13
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
	"arena_opponents": [10005, 10012, 10025],  # Character IDs (10000 + rank)
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
	},
	{
	# Server info (same server as character 1)
	"server_timezone": "Europe/Stockholm",
	"server_day": 50,
	"weather": 2,  # 1=sunny, 2=rainy
	"location": 1,
	
	# Character info
	"character_id": 2,
	"name": "Warrior2",
	"faction": 2,
	"rank": 8523,
	"avatar": [1, 11, 20, 30, 40],  # [face, hair, eyes, nose, mouth]
	"stats": [15, 10, 8, 12, 8, 8, 15],  # [strength, stamina, agility, luck, armor, damage_min, damage_max]
	"silver": 2500,
	"talent_points": 5,
	"blessing": 50,
	"potion": 0,
	"elixir": [500, 501],  # Array of ingredient IDs when active, empty when none
	
	# Flags and state
	"vip": true,
	"autoskip": true,
	"traveling": null,
	"traveling_destination": null,
	"dungeon": false,
	"daily_quests": [1, 5],
	"quest_log": [],
	"expedition": [],  # Array: [current_slide] when active, empty when not on expedition
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
			"day": 10
		}
	],
	"perks": [
		{
			"id": 2,
			"active": true,
			"slot": 1
		}
	],
	"talents": [
		{
			"talent_id": 3,
			"points": 2
		}
	],
	"arena_opponents": [10008, 10015, 10030],  # Character IDs (10000 + rank)
	"vendor_items": [2, 2, 3, 3, 4, 4, 1, 1],
	"enchanter_effects": [5, 6, 7, 8],
	"rankings": [],  # Will be populated in _ready()
	"chat_messages": [
		{
			"sender": "Town Crier",
			"timestamp": "2025-08-08T11:00:00Z",
			"status": "peasant",
			"message": "New bounties posted at the guild hall!",
			"type": "local"
		},
		{
			"sender": "Guard",
			"timestamp": "2025-08-08T11:05:00Z",
			"status": "lord",
			"message": "Stay alert, travelers have reported bandits on the road.",
			"type": "global"
		}
	]
	}
]

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


# ============================================
# WEBSOCKET API - Game Actions
# ============================================

func send(action: String, payload: Dictionary):
	"""Send a WebSocket action to the server (placeholder for now)"""
	print("[WS] Action: ", action, " | Payload: ", payload)
	# TODO: Implement actual WebSocket sending when connected to real server

# ============================================
# Item Management Actions
# ============================================

func move_item(slot_from: int, slot_to: int):
	"""Move item from one slot to another"""
	send("move_item", {
		"int_argument1": slot_from,
		"int_argument2": slot_to
	})

func sell_item(slot_id: int):
	"""Sell an item from inventory"""
	send("sell_item", {
		"int_argument1": slot_id
	})

func socket_item(gem_slot: int, target_slot: int):
	"""Socket a gem/rune into an item"""
	send("socket_item", {
		"int_argument1": gem_slot,
		"int_argument2": target_slot
	})

func buy_item(item_id: int, target_slot: int):
	"""Buy an item from vendor"""
	send("buy_item", {
		"int_argument1": item_id,
		"int_argument2": target_slot
	})

func enchant_item(slot_id: int, effect_id: int):
	"""Enchant an item with an effect"""
	send("enchant_item", {
		"int_argument1": slot_id,
		"int_argument2": effect_id
	})

func temper_item(slot_id: int):
	"""Temper/upgrade an item"""
	send("temper_item", {
		"int_argument1": slot_id
	})

# ============================================
# Character/Stat Training Actions
# ============================================

func train_stat(stat: int):
	"""Train a character stat (stat ID)"""
	send("train_stat", {
		"int_argument1": stat
	})

func add_talent(talent_id: int):
	"""Add a talent point to a talent"""
	send("add_talent", {
		"int_argument1": talent_id
	})

func reset_talents():
	"""Reset all talent points"""
	send("reset_talents", {})

# ============================================
# Blessing/Perk/Utility Actions
# ============================================

func choose_blessing(blessing_slot: int):
	"""Choose a blessing/buff effect"""
	send("choose_blessing", {
		"int_argument1": blessing_slot
	})

func activate_perk(talent_id: int, perk_id: int):
	"""Activate a perk with a talent"""
	send("activate_perk", {
		"int_argument1": talent_id,
		"int_argument2": perk_id
	})

# ============================================
# Consumable/Item Usage Actions
# ============================================

func brew_elixir(slot1: int, slot2: int = -1, slot3: int = -1):
	"""Brew elixir from ingredients (slot1 required, slot2/3 optional)"""
	var payload = {"int_argument1": slot1}
	if slot2 >= 0:
		payload["int_argument2"] = slot2
	if slot3 >= 0:
		payload["int_argument3"] = slot3
	send("brew_elixir", payload)

func use_elixir(slot_id: int):
	"""Use an elixir from inventory"""
	send("use_elixir", {
		"int_argument1": slot_id
	})

func use_potion(slot_id: int):
	"""Use a potion from inventory"""
	send("use_potion", {
		"int_argument1": slot_id
	})

func use_hammer(hammer_slot: int, target_slot: int):
	"""Use a hammer on an item"""
	send("use_hammer", {
		"int_argument1": hammer_slot,
		"int_argument2": target_slot
	})

func use_scroll(scroll_slot: int, target_slot: int):
	"""Use a scroll on an item"""
	send("use_scroll", {
		"int_argument1": scroll_slot,
		"int_argument2": target_slot
	})

# ============================================
# Quest Actions
# ============================================

func quest_option(option_id: int):
	"""Choose a quest dialog option"""
	send("quest_option", {
		"int_argument1": option_id
	})

func accept_quest(quest_id: int):
	"""Accept a quest (new implementation)"""
	send("accept_quest", {
		"int_argument1": quest_id
	})

func quest_cancel():
	"""Cancel current quest"""
	send("quest_cancel", {})

func skip_travel():
	"""Skip travel time"""
	send("skip_travel", {})

# ============================================
# Combat/Encounter Actions
# ============================================

func load_enemy(character_id: int):
	"""Load enemy character data"""
	send("load_enemy", {
		"int_argument1": character_id
	})

func load_rankings(direction: int, reference_rank: int):
	"""Load rankings leaderboard (direction: 1=up, 2=down, 3=center)"""
	send("load_rankings", {
		"int_argument1": direction,
		"int_argument2": reference_rank
	})

func fight_player(enemy_id: int):
	"""Initiate combat with another player"""
	send("fight_player", {
		"int_argument1": enemy_id
	})

func send_chat(chat_type: int, message: String):
	"""Send a chat message (1=local, 2=global)"""
	send("send_chat", {
		"int_argument1": chat_type,
		"string_argument": message
	})

func start_expedition():
	"""Start an expedition - server knows which one based on player location"""
	send("start_expedition", {})

func expedition_option(option_id: int):
	"""Choose an expedition option (server will respond with next slide)"""
	send("expedition_option", {
		"int_argument1": option_id
	})
	
	# MOCK: Simulate server response with random next slide (1-4)
	# In production, this would come from the server
	var random_slide = randi_range(1, 4)
	print("MOCK: Server responded with next slide ID: ", random_slide)
	
	# Call the expedition panel to show the next slide
	if UIManager.instance and UIManager.instance.expedition_panel:
		UIManager.instance.expedition_panel.receive_next_slide(random_slide)

