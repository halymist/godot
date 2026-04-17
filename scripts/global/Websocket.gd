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
		"expeditionOptionResponse":
			_handle_expedition_option_response(data)
		"expeditionCancelResponse":
			_handle_simple_response(data, "expeditionCancel")
		"questOptionResponse":
			_handle_quest_option_response(data)
		"questCancelResponse":
			_handle_quest_cancel_response(data)
		"acceptQuestResponse":
			_handle_accept_quest_response(data)
		"localChat":
			_handle_chat_message(data, "local")
		"globalChat":
			_handle_chat_message(data, "global")
		"combatLog":
			_handle_combat_log(data)
		"sellItemResponse", "sellItemsResponse":
			_handle_sell_item_response(data)
		"temperItemResponse":
			_handle_simple_response(data, "temperItem")
		"resetTalentsResponse":
			_handle_simple_response(data, "resetTalents")
		"trainStatResponse":
			_handle_simple_response(data, "trainStat")
		"addTalentResponse":
			_handle_simple_response(data, "addTalent")
		"buyItemResponse":
			_handle_simple_response(data, "buyItem")
		"buyItemVendorResponse":
			_handle_simple_response(data, "buyItemVendor")
		"enchantItemResponse":
			_handle_simple_response(data, "enchantItem")
		"chooseBlessingResponse":
			_handle_simple_response(data, "chooseBlessing")
		"activatePerkResponse":
			_handle_simple_response(data, "activatePerk")
		"brewElixirResponse":
			_handle_simple_response(data, "brewElixir")
		"useElixirResponse":
			_handle_simple_response(data, "useElixir")
		"usePotionResponse":
			_handle_simple_response(data, "usePotion")
		"useHammerResponse":
			_handle_simple_response(data, "useHammer")
		"useScrollResponse":
			_handle_simple_response(data, "useScroll")
		"moveItemResponse":
			_handle_simple_response(data, "moveItem")
		"socketItemResponse":
			_handle_simple_response(data, "socketItem")
		"skipTravelResponse":
			_handle_simple_response(data, "skipTravel")
		"loadEnemyResponse":
			_handle_load_enemy_response(data)
		"rankingsData":
			_handle_rankings_data(data)
		"error":
			_handle_error(data)
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

func _handle_expedition_option_response(message: Dictionary):
	"""Handle expeditionOptionResponse - server returns {data: [{success: true, slide_id: X, message: "..."}]}"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid expeditionOptionResponse format")
		return

	var data = message.data[0]
	# Update depleted health if provided by server
	if GameInfo.current_player and data.has("depleted_health"):
		var max_health = GameInfo.current_player.get_total_stats().stamina * 10
		GameInfo.current_player.depleted_health = clamp(int(data.get("depleted_health", 0)), 0, max_health)
		if UIManager.instance:
			UIManager.instance.refresh_stats()
	if not data.get("success", false):
		print("[WebSocket] Expedition option failed: ", data.get("message", ""))
		# If combat data exists, show combat and defer failure handling
		if data.has("combat") and data.combat is Dictionary:
			GameInfo.current_combat_log = GameInfo.CombatResponse.new(data.combat)
			if GameInfo.current_player and not data.has("depleted_health"):
				var max_health = GameInfo.current_player.get_total_stats().stamina * 10
				GameInfo.current_player.depleted_health = clamp(int(GameInfo.current_combat_log.player_depleted_health), 0, max_health)
				if UIManager.instance:
					UIManager.instance.refresh_stats()
			GameInfo.pending_expedition_slide_id_after_combat = 0
			GameInfo.pending_expedition_failure_message = data.get("message", "")

			if UIManager.instance and UIManager.instance.combat_panel:
				var combat_panel = UIManager.instance.combat_panel
				combat_panel.prepare_combat()
				await Engine.get_main_loop().process_frame
				UIManager.instance.show_panel(combat_panel)
			return

		if UIManager.instance and UIManager.instance.expedition_panel:
			UIManager.instance.expedition_panel.handle_expedition_failed(data.get("message", ""))
		return

	# Handle expedition end response (keep panel visible with placeholder text)
	if data.get("end", false):
		if UIManager.instance and UIManager.instance.expedition_panel:
			UIManager.instance.expedition_panel.handle_expedition_end(data.get("message", ""))
		return

	var slide_id = int(data.get("slide_id", 0))
	print("[WebSocket] Expedition option processed - slide_id: ", slide_id)

	# If combat data is included, show combat panel first and defer slide advance
	if data.has("combat") and data.combat is Dictionary:
		GameInfo.current_combat_log = GameInfo.CombatResponse.new(data.combat)
		if GameInfo.current_player and not data.has("depleted_health"):
			var max_health = GameInfo.current_player.get_total_stats().stamina * 10
			GameInfo.current_player.depleted_health = clamp(int(GameInfo.current_combat_log.player_depleted_health), 0, max_health)
			if UIManager.instance:
				UIManager.instance.refresh_stats()
		GameInfo.pending_expedition_slide_id_after_combat = slide_id

		if UIManager.instance and UIManager.instance.combat_panel:
			var combat_panel = UIManager.instance.combat_panel
			combat_panel.prepare_combat()
			await Engine.get_main_loop().process_frame
			UIManager.instance.show_panel(combat_panel)
		return

	if UIManager.instance and UIManager.instance.expedition_panel:
		UIManager.instance.expedition_panel.receive_next_slide(slide_id)

func _handle_chat_message(message: Dictionary, chat_type: String):
	"""Handle incoming chat messages (localChat or globalChat)"""
	if not message.has("data") or not message.data is Array:
		print("[WebSocket] Invalid chat message format")
		return
	
	for chat_data in message.data:
		# Server sends: {id, lobby_id, message, character_name, timestamp}
		var sender_name = chat_data.get("character_name", "Unknown")
		
		var chat_message_data = {
			"sender": sender_name,
			"message": chat_data.get("message", ""),
			"timestamp": _unix_to_iso(chat_data.get("timestamp", 0)),
			"type": chat_type,
			"status": "peasant"  # TODO: Get from server if available
		}
		
		# Add to GameInfo chat messages
		var chat_message = GameInfo.ChatMessage.new(chat_message_data)
		GameInfo.chat_messages.append(chat_message)
		print("[WebSocket] Chat message added: ", sender_name, ": ", chat_data.get("message", ""))
	
	# Notify ChatPanel (ChatOverlay) to refresh display
	if UIManager.instance and UIManager.instance.chat_panel:
		UIManager.instance.chat_panel.display_chat_messages()

func _get_player_name(player_id: String) -> String:
	"""Get player name from ID, checking current player and enemy players"""
	if GameInfo.current_player and str(GameInfo.current_player.character_id) == player_id:
		return GameInfo.current_player.name
	
	for player in GameInfo.enemy_players:
		if str(player.character_id) == player_id:
			return player.name
	
	return "Player " + player_id

func _get_player_status(player_id: String) -> String:
	"""Get player status (lord/peasant) from ID"""
	if GameInfo.current_player and str(GameInfo.current_player.character_id) == player_id:
		return "lord" if GameInfo.current_player.premium else "peasant"
	
	for player in GameInfo.enemy_players:
		if str(player.character_id) == player_id:
			return "lord" if player.premium else "peasant"
	
	return "peasant"

func _unix_to_iso(unix_timestamp: int) -> String:
	"""Convert Unix timestamp to ISO 8601 format"""
	if unix_timestamp == 0:
		return ""
	var datetime = Time.get_datetime_dict_from_unix_time(unix_timestamp)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

func _handle_combat_log(message: Dictionary):
	"""Handle combatLog response from server"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid combatLog format")
		# Reset fight button on error
		if UIManager.instance and UIManager.instance.arena_panel:
			UIManager.instance.arena_panel.reset_fight_button()
		return
	
	var combat_data = message.data[0]
	print("[WebSocket] Combat log received")
	
	# Create CombatResponse from server data
	GameInfo.current_combat_log = GameInfo.CombatResponse.new(combat_data)
	
	# Reset the arena fight button
	if UIManager.instance and UIManager.instance.arena_panel:
		UIManager.instance.arena_panel.reset_fight_button()
	
	# Prepare and show combat panel
	if UIManager.instance and UIManager.instance.combat_panel:
		var combat_panel = UIManager.instance.combat_panel
		
		# Prepare all visuals while panel is still hidden
		combat_panel.prepare_combat()
		
		# Wait one frame for Godot to process UI updates before showing
		await Engine.get_main_loop().process_frame
		
		# Now show the panel - playback starts via visibility_changed
		UIManager.instance.show_panel(combat_panel)

func _handle_quest_option_response(message: Dictionary):
	"""Handle questOptionResponse from server"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid questOptionResponse format")
		return
	
	var response = message.data[0]
	var success = response.get("success", false)
	var msg = response.get("message", "")
	
	if not success:
		print("[WebSocket] Quest option failed: ", msg)
		# If server says we're not on a quest, could be a desync
		return
	
	print("[WebSocket] Quest option success: ", msg)
	# Server confirmed the option - client already applied it optimistically

func _handle_quest_cancel_response(message: Dictionary):
	"""Handle questCancelResponse from server"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid questCancelResponse format")
		return
	
	var response = message.data[0]
	var success = response.get("success", false)
	var msg = response.get("message", "")
	
	print("[WebSocket] Quest cancel response: success=", success, " message=", msg)

func _handle_accept_quest_response(message: Dictionary):
	"""Handle acceptQuestResponse from server"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid acceptQuestResponse format")
		return
	
	var response = message.data[0]
	var success = response.get("success", false)
	var msg = response.get("message", "")
	
	if success:
		print("[WebSocket] Quest accepted: ", msg)
	else:
		print("[WebSocket] Quest accept failed: ", msg)

func _handle_simple_response(message: Dictionary, action_name: String):
	"""Generic handler for optimistic actions - log result, sync silver if provided"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid ", action_name, "Response format")
		return

	var response = message.data[0]
	var success = response.get("success", false)
	var msg = response.get("message", "")

	if success:
		# Server may provide authoritative silver total
		if response.has("silver") and GameInfo.current_player:
			GameInfo.current_player.silver = int(response.silver)
			if UIManager.instance:
				UIManager.instance.update_display()
		print("[WebSocket] ", action_name, " success: ", msg)
	else:
		print("[WebSocket] ", action_name, " FAILED: ", msg)

func _handle_sell_item_response(message: Dictionary):
	"""Handle sellItemResponse - server may return authoritative silver"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid sellItemResponse format")
		return

	var response = message.data[0]
	var success = response.get("success", false)
	var msg = response.get("message", "")

	if success:
		# Server may provide authoritative silver total
		if response.has("silver") and GameInfo.current_player:
			GameInfo.current_player.silver = int(response.silver)
			if UIManager.instance:
				UIManager.instance.update_display()
		print("[WebSocket] sellItem success: ", msg)
	else:
		print("[WebSocket] sellItem FAILED: ", msg)

func _handle_load_enemy_response(message: Dictionary):
	"""Handle loadEnemyResponse - server returns enemy character data"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Invalid loadEnemyResponse format")
		return

	var enemy_data = message.data[0]
	print("[WebSocket] Enemy data received: ", enemy_data.get("name", "unknown"))

	# Create enemy player object and show enemy panel
	var enemy = GameInfo.GamePlayer.new(enemy_data, GameInfo)
	if UIManager.instance:
		UIManager.instance.enemy_character_display.display_enemy(enemy.name)
		UIManager.instance.show_overlay(UIManager.instance.enemy_panel)

func _handle_rankings_data(message: Dictionary):
	"""Handle rankingsData - server returns array of minimal ranking entries"""
	if not message.has("data") or not message.data is Array:
		print("[WebSocket] Invalid rankingsData format")
		return

	var players_data = message.data
	var new_players: Array = []

	for ranking_entry in players_data:
		if not ranking_entry is Dictionary:
			continue
		# Transform minimal server format to full GamePlayer-compatible dict
		var player_data = {
			"character_id": ranking_entry.get("character_id", 0),
			"name": ranking_entry.get("character_name", ""),
			"faction": ranking_entry.get("faction", 1),
			"honor": ranking_entry.get("honnor", 0),
			"vip": ranking_entry.get("vip", false),
			"rank": ranking_entry.get("rank", 0),
			"profession": 0,
			"avatar": [40, 48, 33, 88, 80, 0, 0, 0],
			"stats": [10, 10, 10, 10, 5, 1, 3],
			"blessing": 0,
			"potion": 0,
			"elixir": [],
			"bag_slots": [],
			"perks": [],
			"talents": []
		}
		var player = GameInfo.GamePlayer.new(player_data, GameInfo)
		new_players.append(player)
		# Merge into global rankings list
		var exists = false
		for i in range(GameInfo.rankings_players.size()):
			if GameInfo.rankings_players[i].rank == player.rank:
				GameInfo.rankings_players[i] = player
				exists = true
				break
		if not exists:
			GameInfo.rankings_players.append(player)

	GameInfo.rankings_players.sort_custom(func(a, b): return a.rank < b.rank)

	# Notify rankings panel
	if UIManager.instance and UIManager.instance.rankings_panel:
		var rankings = UIManager.instance.rankings_panel
		if rankings.is_loading_up:
			rankings.append_rankings_up(new_players)
		elif rankings.is_loading_down:
			rankings.append_rankings_down(new_players)

func _handle_error(message: Dictionary):
	"""Handle server error messages"""
	if not message.has("data") or not message.data is Array or message.data.size() == 0:
		print("[WebSocket] Error with no data")
		return

	var error_data = message.data[0]
	var msg = error_data.get("message", "Unknown error")
	print("[WebSocket] Server error: ", msg)

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
	"""Send a chat message (0=local, 1=global)"""
	send("chat", {
		"int_argument1": chat_type,
		"string_argument": message
	})

func start_expedition():
	"""Start an expedition - server knows which one based on player location"""
	send("start_expedition", {})

func expedition_cancel():
	"""Cancel current expedition"""
	send("expedition_cancel", {})

func expedition_option(option_id: int):
	"""Choose an expedition option (server will respond with next slide)"""
	send("expedition_option", {
		"int_argument1": option_id
	})
