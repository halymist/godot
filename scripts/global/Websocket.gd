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

func _ready():
	print("Websocket ready!")
	set_process(false)  # Only process when connected

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
		"startExpeditionResponse":
			_handle_start_expedition_response(data)
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

func _handle_start_expedition_response(message: Dictionary):
	"""Handle startExpeditionResponse - server returns {data: [{started: true, slide_id: X, arrival: timestamp}]}"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid startExpeditionResponse format")
		return
	
	var data = message.data[0]
	
	if not data.get("started", false):
		print("[WebSocket] Expedition start failed")
		return
	
	var slide_id = data.get("slide_id", 0)
	var arrival = data.get("arrival", "")
	
	print("[WebSocket] Expedition started - slide_id: ", slide_id, ", arrival: ", arrival)
	
	# Pass to MapPanel to handle the travel timer with server-provided arrival time
	if UIManager.instance and UIManager.instance.map_panel:
		UIManager.instance.map_panel.receive_expedition_start(slide_id, arrival)

# ============================================
# WEBSOCKET API - Game Actions
# ============================================

func send(action: String, payload: Dictionary):
	"""Send a WebSocket action to the server"""
	if not connected or not ws:
		print("[WS] Not connected! Cannot send action: ", action)
		return
	
	# Build message with action as function name
	var message = {"function": action}
	
	# Add payload fields to message
	for key in payload:
		message[key] = payload[key]
	
	var json = JSON.stringify(message)
	print("[WS] Sending ", action, ": ", json)
	ws.send_text(json)

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
