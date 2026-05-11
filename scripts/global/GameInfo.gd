extends Node

# Persistent game data manager - AutoLoad
# This holds all player data permanently, separate from UI

# ============================================
# DATABASE REFERENCES
# ============================================
var effects_db: EffectDatabase = null
var items_db: ItemDatabase = null
var perks_db: PerkDatabase = null
var cosmetics_db: CosmeticDatabase = null
var settlements_db: SettlementsDatabase = null
var quests_db: QuestsDatabase = null
var enemies_db: EnemyDatabase = null
var expeditions_db: Resource = null  # ExpeditionsDatabase
var talents_db: Resource = null  # TalentsDatabase

# ============================================
# RUNTIME DATA
# ============================================
# Lobby data (account info, server list, character list)
var lobby_data: Dictionary = {}
var last_auth_response: Dictionary = {}
var user_id: String = ""

# Timestamp when the currently selected server was created (for day calculation)
var server_created_at: int = 0
var current_server_id: int = 0

# Skip auto-login after explicit logout
var skip_auto_login_once: bool = false

# Character management
var all_characters: Array[GameCurrentPlayer] = []
var current_character_id: int = 0

# World data (populated per character)
var enemy_players: Array[GamePlayer] = []
var rankings_players: Array[GamePlayer] = []  # Unified list: enemy_players + current_player (no duplicates)
var arena_opponents: Array[int] = []
var chat_messages: Array[ChatMessage] = []
var current_combat_log: CombatResponse = null
var pending_expedition_failure_message: String = ""
var pending_quest_failure_message: String = ""

# Talent registry (populated by Talent.gd nodes on _ready)
var talent_registry: Dictionary = {}

# ============================================
# SIGNALS
# ============================================
signal quest_completed(quest_id)

# ============================================
# COMPUTED PROPERTIES
# ============================================
var current_player: GameCurrentPlayer:
	get:
		for character in all_characters:
			if character.character_id == current_character_id:
				return character
		return null

# ============================================
# INITIALIZATION
# ============================================
var databases_loaded: bool = false

func load_databases():
	"""Call this from lobby scene to load all game databases"""
	if databases_loaded:
		return  # Already loaded
	
	
	# Get databases from DataManager (loaded from JSON)
	effects_db = DataManager.get_effects_database()
	items_db = DataManager.get_items_database()
	perks_db = DataManager.get_perks_database()
	enemies_db = DataManager.get_enemies_database()
	expeditions_db = DataManager.get_expeditions_database()
	settlements_db = DataManager.get_settlements_database()
	talents_db = DataManager.get_talents_database()
	quests_db = DataManager.get_quests_database()
	cosmetics_db = DataManager.get_cosmetics_database()
	
	databases_loaded = true

func load_lobby_data():
	"""Load lobby data - deprecated, lobby_data is now set directly from login response"""
	# This function is kept for backwards compatibility but should not be used
	# Lobby data is now set directly by LoginPanel._on_login_completed()
	return

func set_lobby_data(data: Dictionary):
	"""Persist the current lobby payload from auth/lobby responses."""
	lobby_data = data.duplicate(true)
	if not (lobby_data.get("server_list", []) is Array):
		lobby_data["server_list"] = []
	if not lobby_data.has("connected_methods") and lobby_data.has("user_connected_methods"):
		lobby_data["connected_methods"] = lobby_data.get("user_connected_methods", [])
	if not lobby_data.has("user_connected_methods") and lobby_data.has("connected_methods"):
		lobby_data["user_connected_methods"] = lobby_data.get("connected_methods", [])

func has_lobby_data() -> bool:
	return not lobby_data.is_empty()

func get_lobby_data() -> Dictionary:
	"""Get the authoritative lobby payload for login/lobby rendering."""
	return lobby_data

func get_server_list() -> Array:
	"""Get server list from the current lobby payload."""
	var servers = lobby_data.get("server_list", [])
	return servers if servers is Array else []

func clear_lobby_data():
	"""Clear the current lobby/auth payload on explicit account logout."""
	lobby_data.clear()
	last_auth_response.clear()
	current_server_id = 0

func add_lobby_mushrooms(amount: int) -> int:
	"""Add/subtract account-level mushrooms and keep all lobby auth mirrors in sync."""
	if not lobby_data.has("mushrooms"):
		lobby_data["mushrooms"] = 0

	var current_value = int(lobby_data.get("mushrooms", 0))
	var new_value = max(0, current_value + amount)
	lobby_data["mushrooms"] = new_value

	if not last_auth_response.is_empty():
		last_auth_response["mushrooms"] = new_value

	return new_value

func _find_server_index(server_id: int) -> int:
	var servers = get_server_list()
	for i in range(servers.size()):
		var server = servers[i]
		if server is Dictionary and int(server.get("id", 0)) == int(server_id):
			return i
	return -1

func _find_server_index_by_character(character_id: int) -> int:
	var servers = get_server_list()
	for i in range(servers.size()):
		var server = servers[i]
		if not (server is Dictionary):
			continue
		var chars = server.get("characters", [])
		if not (chars is Array):
			continue
		for c in chars:
			if c is Dictionary and int(c.get("character_id", 0)) == int(character_id):
				return i
	return -1

func _build_lobby_character_from_player(player: GameCurrentPlayer) -> Dictionary:
	return {
		"character_id": int(player.character_id),
		"name": player.name,
		"vip": bool(player.vip),
		"faction": int(player.faction),
		"rank": int(player.rank),
		"honnor": int(player.honor),
		"avatar": [
			int(player.avatar_face),
			int(player.avatar_hair),
			int(player.avatar_eyes),
			int(player.avatar_nose),
			int(player.avatar_mouth),
			int(player.avatar_brows),
			int(player.avatar_ears),
			int(player.avatar_special)
		]
	}

func upsert_lobby_character(server_id: int, character: Dictionary):
	if lobby_data.is_empty() or not (lobby_data.get("server_list", []) is Array):
		return
	if not (character is Dictionary):
		return

	var char_id = int(character.get("character_id", 0))
	if char_id <= 0:
		return

	var server_list = lobby_data.get("server_list", [])
	var target_server_index = _find_server_index(server_id)
	if target_server_index < 0:
		target_server_index = _find_server_index_by_character(char_id)

	if target_server_index < 0:
		var fallback_server = {
			"id": int(server_id),
			"name": "Server " + str(server_id),
			"created_at": int(server_created_at),
			"current_day": int(current_player.server_day) if current_player else 0,
			"characters": []
		}
		server_list.append(fallback_server)
		target_server_index = server_list.size() - 1

	var server = server_list[target_server_index]
	if not (server is Dictionary):
		return

	var chars = server.get("characters", [])
	if not (chars is Array):
		chars = []

	var replaced = false
	for i in range(chars.size()):
		var existing = chars[i]
		if existing is Dictionary and int(existing.get("character_id", 0)) == char_id:
			chars[i] = character.duplicate(true)
			replaced = true
			break

	if not replaced:
		chars.append(character.duplicate(true))

	server["characters"] = chars
	server_list[target_server_index] = server
	lobby_data["server_list"] = server_list

func sync_current_player_to_lobby(server_id_override: int = 0):
	var player = current_player
	if not player:
		return

	var server_id = int(server_id_override)
	if server_id <= 0:
		server_id = int(current_server_id)
	if server_id <= 0:
		var idx = _find_server_index_by_character(int(player.character_id))
		if idx >= 0:
			var servers = get_server_list()
			if idx < servers.size() and servers[idx] is Dictionary:
				server_id = int(servers[idx].get("id", 0))

	if server_id <= 0:
		return

	upsert_lobby_character(server_id, _build_lobby_character_from_player(player))
	current_server_id = server_id

# ============================================
# PERK DATA REFRESH
# ============================================
func refresh_all_perks():
	"""Refresh all perks for current player from databases. Call after databases are loaded."""
	if current_player:
		for perk in current_player.perks:
			perk.refresh_from_database()
	for character in all_characters:
		for perk in character.perks:
			perk.refresh_from_database()

# ============================================
# TALENT REGISTRATION
# ============================================
func register_talent(id: int, effect_id: int, factor: float, max_points: int, perk_slot: bool = false):
	talent_registry[id] = {
		"effect_id": effect_id,
		"factor": factor,
		"max_points": max_points,
		"perk_slot": perk_slot  # bool: true if this talent unlocks a perk slot
	}

# ============================================
# CHARACTER MANAGEMENT
# ============================================

class Item:
	extends RefCounted
	
	# Server data (user-specific modifications)
	var id: int = 0
	var bag_slot_id: int = 0
	var day: int = 0  # Day when item was acquired (for stat scaling: 2% per day)
	var effect_overdrive: int = 0  # Enchanting overdrive level
	var tempered: int = 0  # Tracks tempering level (0 = not tempered, 1+ = tempered)
	var socket_id: int = -1  # ID of socketed gem (-1 = empty socket)
	var socket_day: int = 0  # Day value of socketed gem for stat scaling
	var ingredients: Array[int] = []  # Ingredient IDs for elixirs (id=1000)
	var elixir_effects: Array[Dictionary] = []  # Direct elixir effects from server: [{effect_id, factor}]
	
	# Client-side cache (not serialized)
	var texture: Texture2D = null
	var _resource_cache: ItemResource = null
	
	func _init(data: Dictionary = {}):
		for key in data:
			if key == "ingredients":
				ingredients.clear()
				for ingredient_id in data[key]:
					if ingredient_id != null and ingredient_id is int:
						ingredients.append(ingredient_id)
			elif key == "elixir_effects":
				elixir_effects.clear()
				for entry in data[key]:
					if entry is Dictionary:
						var parsed_effect_id = int(entry.get("effect_id", 0))
						var parsed_factor = float(entry.get("factor", 0.0))
						if parsed_effect_id > 0:
							elixir_effects.append({"effect_id": parsed_effect_id, "factor": parsed_factor})
			elif key in self:
				set(key, data[key])
		
		if GameInfo and GameInfo.items_db:
			var res = get_resource()
			if res:
				texture = res.icon
	
	# Helper to get ItemResource (cached)
	func get_resource() -> ItemResource:
		if _resource_cache == null:
			_resource_cache = GameInfo.items_db.get_item_by_id(id)
		return _resource_cache
	
	# Property getters for static data (looked up from items_db)
	var item_name: String:
		get:
			var res = get_resource()
			return res.item_name if res else ""
	
	var type: String:
		get:
			var res = get_resource()
			return res.get_type_string() if res else ""
	
	var price: int:
		get:
			var res = get_resource()
			return res.price if res else 0
	
	var has_socket: bool:
		get:
			var res = get_resource()
			return res.has_socket if res else false
	
	# Centralized stat calculation - apply day scaling (2% per day) and tempering (10% per level)
	static func calculate_scaled_value(base: int, day_value: int, tempered_value: int) -> int:
		"""Apply day scaling and tempering to any stat value"""
		if base == 0:
			return 0
		
		# First, apply day scaling and round
		var result = float(base)
		if day_value > 0:
			result = result * pow(1.02, day_value)
		result = round(result)
		
		# Then apply tempering bonus iteratively (10% per level with rounding at each step)
		for i in range(tempered_value):
			result = round(result * 1.1)
		
		return int(result)
	
	# Stat properties - directly calculate scaled values from resource
	var strength: int:
		get:
			var res = get_resource()
			return calculate_scaled_value(res.strength if res else 0, day, tempered)
	
	var stamina: int:
		get:
			var res = get_resource()
			return calculate_scaled_value(res.stamina if res else 0, day, tempered)
	
	var agility: int:
		get:
			var res = get_resource()
			return calculate_scaled_value(res.agility if res else 0, day, tempered)
	
	var luck: int:
		get:
			var res = get_resource()
			return calculate_scaled_value(res.luck if res else 0, day, tempered)
	
	var armor: int:
		get:
			var res = get_resource()
			return calculate_scaled_value(res.armor if res else 0, day, tempered)
	
	var damage_min: int:
		get:
			var res = get_resource()
			return calculate_scaled_value(res.damage_min if res else 0, day, tempered)
	
	var damage_max: int:
		get:
			var res = get_resource()
			return calculate_scaled_value(res.damage_max if res else 0, day, tempered)
	
	# Effect properties
	var effect_id: int:
		get:
			if effect_overdrive > 0:
				return effect_overdrive
			var res = get_resource()
			return res.effect_id if res else 0
	
	var effect_factor: float:
		get:
			if effect_overdrive > 0 and GameInfo and GameInfo.effects_db:
				var effect = GameInfo.effects_db.get_effect_by_id(effect_overdrive)
				return effect.factor if effect else 0.0
			var res = get_resource()
			return res.effect_factor if res else 0.0
	
	var effect_name: String:
		get:
			if effect_id > 0 and GameInfo and GameInfo.effects_db:
				var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
				return effect.name if effect else ""
			return ""
	
	var effect_description: String:
		get:
			if effect_id > 0 and GameInfo and GameInfo.effects_db:
				var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
				return effect.description if effect else ""
			return ""
	
	func get_socketed_gem() -> Item:
		"""Get the socketed gem as an Item (gems are just items with scaling)"""
		if socket_id > 0 and GameInfo:
			return Item.new({
				"id": socket_id,
				"day": socket_day
			})
		return null

class Perk:
	extends RefCounted
	
	# JSON properties (only dynamic data from server)
	var id: int = 0
	var active: bool = false
	var slot: int = 0
	
	# Static data (loaded from perks_db)
	var perk_name: String = ""
	var effect1_id: int = 0
	var effect1: String = ""  # Looked up from effects_db
	var effect1_description: String = ""  # Full effect description for tooltip
	var factor1: float = 0.0
	var effect2_id: int = 0
	var effect2: String = ""  # Looked up from effects_db
	var effect2_description: String = ""  # Full effect description for tooltip
	var factor2: float = 0.0
	
	# Client-side only
	var texture: Texture2D = null
	
	func _init(data: Dictionary = {}):
		# Simple direct assignment
		for key in data:
			if key in self:
				set(key, data[key])
		
		# Try to load static data from databases
		refresh_from_database()
	
	func refresh_from_database():
		"""Refresh perk data from perks_db and effects_db. Call this if databases weren't ready during _init."""
		if not GameInfo or not GameInfo.perks_db:
			return
		
		var perk_resource = GameInfo.perks_db.get_perk_by_id(id)
		if perk_resource:
			# Copy static data from resource
			perk_name = perk_resource.perk_name
			effect1_id = perk_resource.effect1_id
			factor1 = perk_resource.factor1
			effect2_id = perk_resource.effect2_id
			factor2 = perk_resource.factor2
			# Texture might be null if not loaded yet - that's OK
			texture = perk_resource.icon if perk_resource.icon else null
			
			# Look up effect details from effects_db
			if GameInfo.effects_db:
				if effect1_id > 0:
					var effect = GameInfo.effects_db.get_effect_by_id(effect1_id)
					if effect:
						effect1 = effect.name
						effect1_description = effect.description
				if effect2_id > 0:
					var effect2_res = GameInfo.effects_db.get_effect_by_id(effect2_id)
					if effect2_res:
						effect2 = effect2_res.name
						effect2_description = effect2_res.description

class Talent:
	extends RefCounted
	
	# JSON properties matching C# Talent class
	var talent_id: int = 0
	var points: int = 0
	
	func _init(data: Dictionary = {}):
		# Simple direct assignment
		for key in data:
			if key in self:
				set(key, data[key])

class ChatMessage:
	extends RefCounted
	
	# Chat message properties
	var sender: String = ""
	var timestamp: String = ""
	var status: String = "peasant"  # "peasant" or "lord"
	var message: String = ""
	var type: String = "global"  # "global" or "local"
	
	func _init(data: Dictionary = {}):
		# Simple direct assignment
		for key in data:
			if key in self:
				set(key, data[key])

class CombatLogEntry:
	extends RefCounted
	
	var turn: int = 0
	var character_id: int = 0
	var action: String = ""
	var factor: int = 0
	var effect_id: int = 0
	var trigger_type: String = ""
	var duration: int = 0
	var buff_type: String = ""

	func _init(data: Dictionary = {}):
		turn = int(data.get("turn", 0))
		character_id = int(data.get("character_id", 0))
		action = str(data.get("action", ""))
		factor = int(data.get("factor", 0))
		effect_id = int(data.get("effect_id", 0))
		trigger_type = str(data.get("trigger_type", ""))
		duration = int(data.get("duration", 0))
		buff_type = str(data.get("buff_type", ""))

class CombatResponse:
	extends RefCounted

	# Player info (from header.player)
	var player_id: int = 0
	var player_name: String = ""
	var player_max_hp: int = 100
	var player_depleted_health: float = 0.0
	var player_avatar: Array = [1, 1, 1, 1]  # [face, hair, eyes, mouth] - 4 elements from server
	
	# Enemy info (from header.enemy)
	var enemy_id: int = 0
	var enemy_name: String = ""
	var enemy_max_hp: int = 100
	var enemy_avatar: Array = [1, 1, 1, 1]
	var enemy_asset_id: int = 0  # NPC asset ID if enemy is NPC (null for players)
	var enemy_npc_id: int = 0
	
	# Result
	var winner_id: int = 0  # character_id of winner
	var combat_type: String = ""  # Optional header type: arena/rankings/quest/replay
	var player_honor: int = -1
	var enemy_honor: int = -1
	var player_hp_end: int = -1
	var enemy_hp_end: int = -1
	var combat_log: Array[CombatLogEntry] = []
	
	func _init(data: Dictionary = {}):
		# Parse header
		var header = data.get("header", {})
		
		# Parse player data
		var player_data = header.get("player", {})
		player_id = int(player_data.get("character_id", 0))
		player_name = player_data.get("name", "")
		player_max_hp = int(player_data.get("max_hp", 100))
		player_depleted_health = float(player_data.get("depleted_health", 0.0))
		if player_data.has("avatar") and player_data.avatar is Array:
			player_avatar = player_data.avatar
		
		# Parse enemy data
		var enemy_data = header.get("enemy", {})
		enemy_id = int(enemy_data.get("character_id", 0))
		enemy_npc_id = int(enemy_data.get("enemy_id", 0))
		enemy_name = enemy_data.get("name", "")
		enemy_max_hp = int(enemy_data.get("max_hp", 100))
		if enemy_data.has("avatar") and enemy_data.avatar is Array:
			enemy_avatar = enemy_data.avatar
		var asset_id = enemy_data.get("asset_id", null)
		if asset_id != null and (asset_id is int or asset_id is float):
			enemy_asset_id = int(asset_id)
		
		# Parse winner
		winner_id = int(header.get("winner", 0))
		combat_type = str(header.get("type", ""))

		# Parse optional end-of-combat HP values
		if header.has("player_hp_end"):
			player_hp_end = int(header.get("player_hp_end", -1))
		if header.has("enemy_hp_end"):
			enemy_hp_end = int(header.get("enemy_hp_end", -1))

		# Parse optional honor updates (support both honor/honnor spellings).
		if header.has("player_honnor"):
			player_honor = int(header.get("player_honnor", -1))
		elif header.has("player_honor"):
			player_honor = int(header.get("player_honor", -1))

		if header.has("enemy_honnor"):
			enemy_honor = int(header.get("enemy_honnor", -1))
		elif header.has("enemy_honor"):
			enemy_honor = int(header.get("enemy_honor", -1))
		
		# Parse combat log
		var log_data = data.get("log", [])
		combat_log.clear()
		for entry in log_data:
			combat_log.append(CombatLogEntry.new(entry))
	
	func has_won() -> bool:
		return winner_id == player_id
	
	func is_enemy_npc() -> bool:
		return enemy_asset_id > 0 or enemy_npc_id > 0

class GamePlayer:
	extends RefCounted
	
	# Events/Signals reference (for emitting from CurrentPlayer)
	var game_info_ref: GameInfo
	
	# Base properties shared by all players
	var character_id: int = 0
	var name: String = ""
	var rank: int = 0
	var faction: int = 0
	var profession: int = 0
	var honor: int = 0
	var strength: int = 0
	var stamina: int = 0
	var agility: int = 0
	var luck: int = 0
	var armor: int = 0
	var damage_min: int = 0
	var damage_max: int = 0
	var avatar_face: int = 40
	var avatar_hair: int = 48
	var avatar_eyes: int = 33
	var avatar_nose: int = 88
	var avatar_mouth: int = 80
	var avatar_brows: int = 0
	var avatar_ears: int = 0
	var avatar_special: int = 0
	var blessing: int = 0  # Active blessing effect ID (0 = no blessing)
	var potion: int = 0  # Equipped potion item ID (0 = no potion)
	var potion_day: int = 0  # Server day when potion effect expires (0 = no expiration tracked)
	var elixir: int = 0  # Equipped elixir item ID (0 = no elixir)
	var elixir_day: int = 0  # Server day when elixir effect expires (0 = no expiration tracked)
	var elixir_ingredients: Array[int] = []  # Ingredients for equipped elixir
	var elixir_effects: Array[Dictionary] = []  # Direct active elixir effects [{effect_id, factor}]
	var depleted_health: int = 0  # Amount of HP lost (0 = full health)
	var bag_slots: Array[Item] = []
	var perks: Array[Perk] = []
	var talents: Array[Talent] = []
	
	func _init(data: Dictionary = {}, game_info: GameInfo = null):
		game_info_ref = game_info
		
		# Load simple properties (excluding arrays and special cases)
		for key in data:
			if key == "elixir":
				# Elixir can be either ingredient ID array (legacy) or direct item id.
				if data[key] is Array and data[key].size() > 0:
					elixir = 1000  # Legacy: elixir represented by ingredient IDs only.
					elixir_ingredients.clear()
					elixir_effects.clear()
					for ingredient_id in data[key]:
						if ingredient_id != null and ingredient_id is int:
							elixir_ingredients.append(ingredient_id)
				elif (data[key] is int or data[key] is float) and int(data[key]) > 0:
					elixir = int(data[key])
				else:
					elixir = 0
					elixir_ingredients.clear()
					elixir_effects.clear()
			elif key == "elixir_ingredients":
				elixir_ingredients.clear()
				for ingredient_id in data[key]:
					if ingredient_id != null and ingredient_id is int:
						elixir_ingredients.append(ingredient_id)
			elif key == "elixir_effects":
				elixir_effects.clear()
				for entry in data[key]:
					if entry is Dictionary:
						var parsed_effect_id = int(entry.get("effect_id", 0))
						var parsed_factor = float(entry.get("factor", 0.0))
						if parsed_effect_id > 0:
							elixir_effects.append({"effect_id": parsed_effect_id, "factor": parsed_factor})
				if elixir_effects.size() > 0 and elixir <= 0:
					elixir = 1000
			elif key in self and key not in ["avatar", "stats", "bag_slots", "perks", "talents"]:
				set(key, data[key])
		
		# Handle avatar array [face, hair, eyes, nose, mouth, brows, ears, special]
		if data.has("avatar") and data.avatar.size() >= 5:
			avatar_face = data.avatar[0]
			avatar_hair = data.avatar[1]
			avatar_eyes = data.avatar[2]
			avatar_nose = data.avatar[3]
			avatar_mouth = data.avatar[4]
			if data.avatar.size() >= 8:
				avatar_brows = data.avatar[5]
				avatar_ears = data.avatar[6]
				avatar_special = data.avatar[7]
		
		# Handle stats array [strength, stamina, agility, luck, armor, damage_min, damage_max]
		if data.has("stats") and data.stats.size() >= 5:
			strength = data.stats[0]
			stamina = data.stats[1]
			agility = data.stats[2]
			luck = data.stats[3]
			armor = data.stats[4]
			if data.stats.size() >= 7:
				damage_min = data.stats[5]
				damage_max = data.stats[6]
		
		# Load arrays
		load_bag_slots(data)
		load_perks(data)
		load_talents(data)
	
	func load_bag_slots(data: Dictionary):
		bag_slots.clear()
		var items_data = data.get("bag_slots", [])
		for item_data in items_data:
			bag_slots.append(Item.new(item_data))
	
	func load_perks(data: Dictionary):
		perks.clear()
		var perks_data = data.get("perks", [])
		for perk_data in perks_data:
			perks.append(Perk.new(perk_data))
	
	func load_talents(data: Dictionary):
		talents.clear()
		var talents_data = data.get("talents", [])
		for talent_data in talents_data:
			talents.append(Talent.new(talent_data))
	
	func get_base_stats() -> Dictionary:
		return {
			"name": name,
			"strength": strength,
			"stamina": stamina,
			"agility": agility,
			"luck": luck,
			"armor": armor,
			"damage_min": damage_min,
			"damage_max": damage_max
		}

	func _add_item_stats(total_stats: Dictionary, item: Item):
		total_stats.strength += item.strength
		total_stats.stamina += item.stamina
		total_stats.agility += item.agility
		total_stats.luck += item.luck
		total_stats.armor += item.armor
		total_stats.damage_min += item.damage_min
		total_stats.damage_max += item.damage_max

	func _add_effect_if_valid(total_effects: Dictionary, effect_id: int, factor: float):
		if effect_id > 0 and effect_id <= 20:
			total_effects[effect_id] += factor
	
	func get_total_stats() -> Dictionary:
		"""Calculate total stats: base + equipped items (including gems) + effect bonuses"""
		var total_stats = get_base_stats()

		# Add stats from equipped items (slots 1-9)
		for item in bag_slots:
			if item.bag_slot_id >= 1 and item.bag_slot_id <= 9:
				_add_item_stats(total_stats, item)
				var gem = item.get_socketed_gem()
				if gem:
					_add_item_stats(total_stats, gem)
		
		# Apply effect bonuses to stats (effects 1-4 boost stats by percentage)
		var total_effects = get_total_effects()
		total_stats.strength = int(round(total_stats.strength * (1.0 + total_effects[1] / 100.0)))
		total_stats.stamina = int(round(total_stats.stamina * (1.0 + total_effects[2] / 100.0)))
		total_stats.agility = int(round(total_stats.agility * (1.0 + total_effects[3] / 100.0)))
		total_stats.luck = int(round(total_stats.luck * (1.0 + total_effects[4] / 100.0)))
		
		return total_stats
	
	func get_damage_range() -> Dictionary:
		"""Calculate final damage range (total damage stats * strength)"""
		var total_stats = get_total_stats()
		return {
			"min": total_stats.damage_min * total_stats.strength,
			"max": total_stats.damage_max * total_stats.strength
		}
	
	func get_total_effects() -> Dictionary:
		# Initialize effect totals for all 20 effects (IDs 1-20)
		var total_effects = {}
		for i in range(1, 21):
			total_effects[i] = 0.0
		
		# 1. Sum effects from equipped items (slots 1-9)
		for item in bag_slots:
			if item.bag_slot_id >= 1 and item.bag_slot_id <= 9:
				_add_effect_if_valid(total_effects, item.effect_id, item.effect_factor)
		
		# 2. Add potion effect (if property exists in subclass)
		if "potion" in self and self.potion > 0 and GameInfo and GameInfo.items_db:
			var potion_item = GameInfo.items_db.get_item_by_id(self.potion)
			if potion_item:
				_add_effect_if_valid(total_effects, potion_item.effect_id, potion_item.effect_factor)
		
		# 3. Add blessing effect (if property exists in subclass)
		if "blessing" in self and self.blessing > 0 and GameInfo and GameInfo.perks_db:
			var blessing_perk = GameInfo.perks_db.get_perk_by_id(self.blessing)
			if blessing_perk:
				_add_effect_if_valid(total_effects, blessing_perk.effect1_id, blessing_perk.factor1)
		
		# 4. Add active perks effects
		var active_perks = get_active_perks()
		for perk in active_perks:
			_add_effect_if_valid(total_effects, perk.effect1_id, perk.factor1)
			_add_effect_if_valid(total_effects, perk.effect2_id, perk.factor2)
		
		# 5. Add elixir effects from elixir_ingredients (if property exists in subclass)
		if "elixir_ingredients" in self and self.elixir_ingredients.size() > 0 and GameInfo and GameInfo.items_db:
			for ingredient_id in self.elixir_ingredients:
				if ingredient_id > 0:
					var ingredient = GameInfo.items_db.get_item_by_id(ingredient_id)
					if ingredient:
						_add_effect_if_valid(total_effects, ingredient.effect_id, ingredient.effect_factor)

		# 5b. Add direct elixir effects from server (fallback when ingredient IDs are unavailable)
		if "elixir_effects" in self and self.elixir_effects.size() > 0:
			for entry in self.elixir_effects:
				var effect_id = int(entry.get("effect_id", 0))
				var factor = float(entry.get("factor", 0.0))
				_add_effect_if_valid(total_effects, effect_id, factor)
		
		# 6. Add talents effects (from runtime registry populated by Talent.gd nodes)
		for talent in talents:
			var talent_id = talent.talent_id
			var points_spent = talent.points
			
			# Look up metadata from registry
			if talent_id in GameInfo.talent_registry:
				var talent_meta = GameInfo.talent_registry[talent_id]
				
				# Skip perk slot talents (they don't provide direct effects)
				if talent_meta.perk_slot:
					continue
				
				# Calculate talent contribution
				_add_effect_if_valid(total_effects, int(talent_meta.effect_id), points_spent * float(talent_meta.factor))
		
		return total_effects
	
	func has_talent(talent_id: int) -> bool:
		for talent in talents:
			if talent.talent_id == talent_id:
				return true
		return false
	
	# Helper function to get active perks
	func get_active_perks() -> Array:
		var active_perks = []
		for perk in perks:
			if perk.active:
				active_perks.append(perk)
		return active_perks
	
	# Helper function to get inactive perks
	func get_inactive_perks() -> Array:
		var inactive_perks = []
		for perk in perks:
			if not perk.active:
				inactive_perks.append(perk)
		return inactive_perks
	
	func get_faction_name() -> String:
		match faction:
			1: return "Order"
			2: return "Guild"
			3: return "Companions"
			_: return "None"
	
	func get_rank_name() -> String:
		# For now always return Novice, later we can add logic based on rank value
		return "Novice"
	

class GameCurrentPlayer:
	extends GamePlayer
	
	# Current player specific properties with automatic events
	var location: int = 1
	var traveling: float = 0.0  # Unix timestamp when travel ends, 0 if not traveling
	var traveling_destination: Variant = null
	var dungeon: bool = false
	var talent_points: int = 0
	var quest_log: Array = []  # Ordered action log: {quest_id: int, option_id: int, finished: bool}
	var daily_quests: Array[int] = []  # Array of quest IDs available today
	var expedition: Array = []  # Array: [current_slide] when active, empty when not on expedition
	var server_timezone: String = "UTC"  # Server's timezone (e.g., "Europe/Stockholm")
	var server_day: int = 1  # Current day on the server (starts at 1)
	var weather: int = 1  # Weather condition (1=sunny, 2=rainy)
	
	# VIP status
	var vip: bool = false
	
	# Silver (no automatic emission - use UIManager.update_display())
	var silver: int = 0
	
	# Active consumable timestamps (Unix timestamp when effect expires)
	var potion_until: float = 0.0
	var elixir_until: float = 0.0
	
	# Shop/service arrays (populated by server)
	var enchanter_effects: Array = []  # Available enchanter effects
	var vendor_items: Array = []  # Items available from vendor
	
	func _init(data: Dictionary = {}, game_info: GameInfo = null):
		# Call parent constructor with data
		super._init(data, game_info)
		
		# Load current player specific fields (excluding special cases)
		for key in data:
			if key in self and key not in ["daily_quests", "quest_log", "avatar", "stats", "bag_slots", "perks", "talents", "vendor_items", "enchanter_effects"]:
				set(key, data[key])
		
		
		# Handle daily_quests array with type conversion
		# Server sends "quests" field, client stores as "daily_quests"
		var quests_data = data.get("daily_quests", data.get("quests", []))
		if quests_data is Array and quests_data.size() > 0:
			daily_quests.clear()
			for quest_id in quests_data:
				daily_quests.append(quest_id as int)
		
		# Handle vendor_items array (item IDs from server)
		if data.has("vendor_items") and data.vendor_items is Array:
			vendor_items = []  # Reset to new array instead of clear()
			for item_id in data.vendor_items:
				vendor_items.append(int(item_id))  # Convert to int
		
		# Handle enchanter_effects array
		if data.has("enchanter_effects") and data.enchanter_effects is Array:
			enchanter_effects.clear()
			for effect_id in data.enchanter_effects:
				enchanter_effects.append(effect_id)
		
		# Handle expedition array
		if data.has("expedition"):
			if data.expedition is Array:
				expedition = data.expedition.duplicate()
		
		# Convert null traveling to 0
		if traveling == null:
			traveling = 0
		
	
	func get_player_stats() -> Dictionary:
		var stats = get_total_stats()
		stats["silver"] = silver
		stats["talent_points"] = talent_points
		return stats
	
	func add_perk_if_new(perk_id: int) -> bool:
		"""Add a perk if player doesn't already have it. Returns true if added, false if already owned."""
		# Check if perk already exists
		for existing_perk in perks:
			if existing_perk.id == perk_id:
				return false
		
		# Perk doesn't exist, add it
		var new_perk = Perk.new({
			"id": perk_id,
			"active": false,
			"slot": 0
		})
		perks.append(new_perk)
		return true
	
	func add_item_to_bag(item_id: int) -> bool:
		"""Add an item to the first available bag slot (10-14). Returns true if added, false if bag is full."""
		# Find empty bag slot (10-14)
		for slot_id in range(10, 15):
			# Check if slot is occupied
			var slot_occupied = false
			for existing_item in bag_slots:
				if existing_item.bag_slot_id == slot_id:
					slot_occupied = true
					break
			
			if not slot_occupied:
				# Found empty slot, create new item with current server day
				var new_item = Item.new({
					"id": item_id,
					"bag_slot_id": slot_id,
					"day": server_day
				})
				bag_slots.append(new_item)
				return true
		
		# No empty slots found
		return false
	
	func check_expired_effects() -> bool:
		"""Check if any active effects have expired based on current time or server_day. Returns true if any effects were removed."""
		var effects_removed = false
		var current_time = Time.get_unix_time_from_system()
		
		# Check potion expiration (timestamp-based)
		if potion > 0 and potion_until > 0 and current_time > potion_until:
			potion = 0
			potion_until = 0.0
			potion_day = 0
			effects_removed = true
		
		# Check potion expiration (day-based fallback)
		if potion > 0 and potion_day > 0 and server_day > potion_day:
			potion = 0
			potion_until = 0.0
			potion_day = 0
			effects_removed = true
		
		# Check elixir expiration (timestamp-based)
		if elixir > 0 and elixir_until > 0 and current_time > elixir_until:
			elixir = 0
			elixir_until = 0.0
			elixir_day = 0
			elixir_ingredients.clear()
			effects_removed = true
		
		# Check elixir expiration (day-based fallback)
		if elixir > 0 and elixir_day > 0 and server_day > elixir_day:
			elixir = 0
			elixir_until = 0.0
			elixir_day = 0
			elixir_ingredients.clear()
			effects_removed = true
		
		return effects_removed

# ============================================
# SERVER DATA TRANSFORMATION
# ============================================

func _transform_server_player_data(server_data: Dictionary) -> Dictionary:
	"""Transform server player data format to client format.
	Server uses different field names and formats than the client expects."""
	
	var client_data = server_data.duplicate(true)
	var normalized_quest_log = _extract_server_quest_log(server_data)
	if normalized_quest_log.size() > 0:
		client_data["quest_log"] = normalized_quest_log
	
	# Field name mappings
	if server_data.has("character_name"):
		client_data["name"] = server_data["character_name"]
		client_data.erase("character_name")
	
	if server_data.has("honnor"):
		client_data["honor"] = server_data["honnor"]
		client_data.erase("honnor")
	
	if server_data.has("settlement_id"):
		client_data["location"] = server_data["settlement_id"]
		client_data.erase("settlement_id")
	
	# Handle avatar: server sends object {face, hair, eyes, nose, mouth, brows, ears, special}, client expects array
	if server_data.has("avatar") and server_data.avatar is Dictionary:
		var avatar_obj = server_data.avatar
		client_data["avatar"] = [
			avatar_obj.get("face", 40),
			avatar_obj.get("hair", 48),
			avatar_obj.get("eyes", 33),
			avatar_obj.get("nose", 88),
			avatar_obj.get("mouth", 80),
			avatar_obj.get("brows", 0),
			avatar_obj.get("ears", 0),
			avatar_obj.get("special", 0)
		]
	
	# Handle stats: server sends object, client expects array
	# [strength, stamina, agility, luck, armor, damage_min, damage_max]
	# Note: Server uses min_damage/max_damage field names
	if server_data.has("stats") and server_data.stats is Dictionary:
		var stats_obj = server_data.stats
		client_data["stats"] = [
			stats_obj.get("strength", 0),
			stats_obj.get("stamina", 0),
			stats_obj.get("agility", 0),
			stats_obj.get("luck", 0),
			stats_obj.get("armor", 0),
			stats_obj.get("min_damage", 0),
			stats_obj.get("max_damage", 0)
		]
	
	# Handle inventory -> bag_slots
	# Server: {slot_id, item_id, server_day, temper, effect_overdrive, factor, socket, socket_day, elixir_effect}
	# Client: {id, bag_slot_id, day, tempered, effect_overdrive, socket_id, socket_day, ingredients}
	if server_data.has("inventory") and server_data.inventory is Array:
		var bag_slots_data = []
		for inv_item in server_data.inventory:
			var client_item = {
				"id": inv_item.get("item_id", 0),
				"bag_slot_id": inv_item.get("slot_id", 0),
				"day": inv_item.get("server_day", 0),
				"tempered": inv_item.get("temper", 0),
				"effect_overdrive": inv_item.get("effect_overdrive", 0),
				"socket_id": inv_item.get("socket", -1) if inv_item.get("socket", null) != null else -1,
				"socket_day": inv_item.get("socket_day", 0)
			}
			# Handle elixir ingredients if item is an elixir
			if inv_item.has("elixir_effect") and inv_item.elixir_effect != null:
				var effects_payload: Array[Dictionary] = []
				var elixir_effect = inv_item.elixir_effect
				if elixir_effect is Dictionary:
					if elixir_effect.has("effect1_id"):
						var e1_id = int(elixir_effect.get("effect1_id", 0))
						var f1 = float(elixir_effect.get("factor1", 0.0))
						if e1_id > 0:
							effects_payload.append({"effect_id": e1_id, "factor": f1})
					if elixir_effect.has("effect2_id"):
						var e2_id = int(elixir_effect.get("effect2_id", 0))
						var f2 = float(elixir_effect.get("factor2", 0.0))
						if e2_id > 0:
							effects_payload.append({"effect_id": e2_id, "factor": f2})
					if elixir_effect.has("effect3_id"):
						var e3_id = int(elixir_effect.get("effect3_id", 0))
						var f3 = float(elixir_effect.get("factor3", 0.0))
						if e3_id > 0:
							effects_payload.append({"effect_id": e3_id, "factor": f3})
					if elixir_effect.has("effect_id"):
						var eid = int(elixir_effect.get("effect_id", 0))
						var ef = float(elixir_effect.get("factor", 0.0))
						if eid > 0:
							effects_payload.append({"effect_id": eid, "factor": ef})
				if effects_payload.size() > 0:
					client_item["elixir_effects"] = effects_payload
			bag_slots_data.append(client_item)
		client_data["bag_slots"] = bag_slots_data
		client_data.erase("inventory")
	
	# Handle perks: server {perk_id, talent_id} -> client {id, slot}
	if server_data.has("perks") and server_data.perks is Array:
		var perks_data = []
		for perk in server_data.perks:
			perks_data.append({
				"id": perk.get("perk_id", 0),
				"slot": perk.get("talent_id", 0),  # talent_id is used as slot
				"active": perk.get("talent_id", 0) > 0  # Active if assigned to a talent
			})
		client_data["perks"] = perks_data
	
	# Handle talents: server {talent_id, points} -> client {talent_id, points}
	# Note: Talent class uses talent_id, not id
	if server_data.has("talents") and server_data.talents is Array:
		var talents_data = []
		for talent in server_data.talents:
			talents_data.append({
				"talent_id": talent.get("talent_id", 0),
				"points": talent.get("points", 0)
			})
		client_data["talents"] = talents_data
	
	# Handle travel fields. Explicitly clear stale state when backend omits or nulls them.
	if server_data.has("destination"):
		client_data["traveling_destination"] = server_data["destination"] if server_data.destination != null else null
	else:
		client_data["traveling_destination"] = null

	if server_data.has("arrival"):
		if server_data.arrival != null:
			# Convert arrival timestamp to unix time
			client_data["traveling"] = _parse_iso_timestamp(server_data["arrival"])
		else:
			client_data["traveling"] = 0.0
	else:
		client_data["traveling"] = 0.0

	# Handle active expedition id and clear legacy state when missing.
	if server_data.has("expedition_id") and server_data.expedition_id != null:
		client_data["expedition"] = [int(server_data.expedition_id)]
	elif server_data.has("active_expedition_id") and server_data.active_expedition_id != null:
		client_data["expedition"] = [int(server_data.active_expedition_id)]
	else:
		client_data["expedition"] = []
	
	# Handle active elixir effects from server fields (effect/factor pairs)
	if server_data.has("elixir_effect1") or server_data.has("elixir_effect2") or server_data.has("elixir_effect3"):
		var elixir_effects = []
		for i in range(1, 4):
			var effect_id = int(server_data.get("elixir_effect" + str(i), 0))
			var factor = float(server_data.get("elixir_factor" + str(i), 0.0))
			if effect_id > 0:
				elixir_effects.append({"effect_id": effect_id, "factor": factor})
		if elixir_effects.size() > 0:
			# Mark elixir as equipped when direct elixir effects are present.
			# Some payloads include an empty legacy field "elixir": [], which still means no id.
			var raw_elixir = client_data.get("elixir", null)
			var has_valid_elixir_id = (raw_elixir is int and int(raw_elixir) > 0)
			if not has_valid_elixir_id:
				client_data["elixir"] = 1000  # Fallback item id for active elixir icon
			client_data["elixir_effects"] = elixir_effects
		# Clean up individual fields
		for i in range(1, 4):
			client_data.erase("elixir_effect" + str(i))
			client_data.erase("elixir_factor" + str(i))
	
	# Handle enchanter and vendor arrays (store for later use)
	if server_data.has("enchanter") and server_data.enchanter is Array:
		client_data["enchanter_effects"] = server_data.enchanter
		client_data.erase("enchanter")
	
	if server_data.has("vendor") and server_data.vendor is Array:
		client_data["vendor_items"] = server_data.vendor
		client_data.erase("vendor")
	
	# Handle timestamps (potion_until, elixir_until) - ISO 8601 strings from server
	if server_data.has("potion_until") and server_data.potion_until != null:
		var timestamp = _parse_iso_timestamp(server_data.potion_until)
		client_data["potion_until"] = timestamp
	if server_data.has("elixir_until") and server_data.elixir_until != null:
		var timestamp = _parse_iso_timestamp(server_data.elixir_until)
		client_data["elixir_until"] = timestamp
	
	# Handle server_day based expiration (potion_day, elixir_day) - legacy support
	if server_data.has("potion_day") and server_data.potion_day != null:
		client_data["potion_day"] = server_data.potion_day
	if server_data.has("elixir_day") and server_data.elixir_day != null:
		client_data["elixir_day"] = server_data.elixir_day
	
	return client_data

func _normalize_quest_log_entries(raw_entries: Variant) -> Array:
	var result: Array = []
	if not (raw_entries is Array):
		return result

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			continue
		var quest_id = int(raw_entry.get("quest_id", raw_entry.get("questId", 0)))
		var option_id = int(raw_entry.get("option_id", raw_entry.get("optionId", 0)))
		if quest_id <= 0 or option_id <= 0:
			continue
		result.append({
			"quest_id": quest_id,
			"option_id": option_id,
			"finished": bool(raw_entry.get("finished", false))
		})

	return result

func _extract_quest_log_from_container(container: Dictionary) -> Array:
	# Try common key variants first.
	var direct = container.get("quest_log", container.get("questLog", container.get("questlog", null)))
	if direct is Array:
		return _normalize_quest_log_entries(direct)
	if direct is String:
		var parsed = JSON.new()
		if parsed.parse(direct) == OK:
			return _normalize_quest_log_entries(parsed.get_data())

	# Try nested wrappers used by some backends.
	for nested_key in ["character", "player", "data"]:
		var nested = container.get(nested_key, null)
		if nested is Dictionary:
			var nested_result = _extract_quest_log_from_container(nested)
			if nested_result.size() > 0:
				return nested_result

	return []

func _extract_server_quest_log(server_data: Dictionary) -> Array:
	if not (server_data is Dictionary):
		return []
	return _extract_quest_log_from_container(server_data)

func _parse_iso_timestamp(iso_string: Variant) -> float:
	"""Parse ISO 8601 timestamp string to Unix timestamp. Returns 0.0 if invalid."""
	if iso_string == null or not iso_string is String or iso_string.is_empty():
		return 0.0
	
	# Try using Godot's built-in parser first
	# Format: "2026-02-01T12:00:00+00:00"
	var datetime_dict = Time.get_datetime_dict_from_datetime_string(iso_string, true)
	if datetime_dict.is_empty():
		return 0.0
	
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime_dict)
	return unix_time

func load_all_characters(characters_data: Array):
	all_characters.clear()
	for char_data in characters_data:
		var player = GameCurrentPlayer.new(char_data, self)
		all_characters.append(player)

func load_character_from_server(character_data: Dictionary):
	"""Load a single character from server data (WebSocket playerData response)"""
	# Preserve server_day before transform (injected by LobbyPanel from server list)
	var injected_server_day = int(character_data.get("server_day", 0))
	
	# Transform server data format to client format
	var transformed_data = _transform_server_player_data(character_data)
	var transformed_quest_log = transformed_data.get("quest_log", [])
	
	all_characters.clear()
	var player = GameCurrentPlayer.new(transformed_data, self)

	# Single quest-log owner: GameInfo hydrates current_player.quest_log at load time.
	player.quest_log = transformed_quest_log.duplicate(true) if transformed_quest_log is Array else []
	
	# Force server_day from lobby server list — the transform/init loop may miss it
	if injected_server_day > 0:
		player.server_day = injected_server_day
	
	all_characters.append(player)
	
	# Check for expired effects based on timestamps
	player.check_expired_effects()
	
	# Automatically select this character
	current_character_id = player.character_id
	_load_character_world_data_from_server(transformed_data)

func select_character(character_id: int):
	current_character_id = character_id

func _load_character_world_data_from_server(char_data: Dictionary):
	"""Load world data from server response (no need to search mock data)"""
	if char_data.is_empty():
		return
	
	# Load rankings if available - transform minimal ranking data to GamePlayer format
	if char_data.has("ranking") and char_data.ranking is Array:
		var rankings_data = []
		for ranking_entry in char_data.ranking:
			# Transform minimal ranking data: {vip, honnor, faction, character_id, character_name, rank}
			# to GamePlayer compatible format with defaults for missing fields
			var player_data = {
				"character_id": ranking_entry.get("character_id", 0),
				"name": ranking_entry.get("character_name", ""),
				"faction": ranking_entry.get("faction", 1),
				"honor": ranking_entry.get("honnor", 0),  # Note: server uses 'honnor' (typo)
				"vip": ranking_entry.get("vip", false),
				"rank": ranking_entry.get("rank", 0),  # Player rank from server
				"profession": 0,
				"avatar": [40, 48, 33, 88, 80, 0, 0, 0],  # Default avatar
				"stats": [10, 10, 10, 10, 5, 1, 3],  # Default stats
				"blessing": 0,
				"potion": 0,
				"elixir": [],
				"bag_slots": [],
				"perks": [],
				"talents": []
			}
			rankings_data.append(player_data)
		load_enemy_players_data(rankings_data)
	
	# Load arena opponents if available - these have full data with stats/avatar
	if char_data.has("arena") and char_data.arena is Array:
		var arena_data = []
		arena_opponents.clear()
		
		for arena_entry in char_data.arena:
			var character_id = int(arena_entry.get("character_id", 0))  # Cast to int (JSON returns float)
			arena_opponents.append(character_id)  # Keep IDs for arena panel
			
			# Transform arena data: {vip, stats{}, avatar{}, honnor, faction, character_id, character_name}
			# Server format has stats/avatar as objects, need to convert to arrays
			var avatar_obj = arena_entry.get("avatar", {})
			var stats_obj = arena_entry.get("stats", {})
			
			var player_data = {
				"character_id": character_id,
				"name": arena_entry.get("character_name", ""),
				"faction": arena_entry.get("faction", 1),
				"honor": arena_entry.get("honnor", 0),
				"vip": arena_entry.get("vip", false),
				# Convert avatar object to array [face, hair, eyes, nose, mouth, brows, ears, special]
				"avatar": [
					avatar_obj.get("face", 40),
					avatar_obj.get("hair", 48),
					avatar_obj.get("eyes", 33),
					avatar_obj.get("nose", 88),
					avatar_obj.get("mouth", 80),
					avatar_obj.get("brows", 0),
					avatar_obj.get("ears", 0),
					avatar_obj.get("special", 0)
				],
				# Convert stats object to array [strength, stamina, agility, luck, armor, damage_min, damage_max]
				# Note: Server uses min_damage/max_damage field names
				"stats": [
					stats_obj.get("strength", 10),
					stats_obj.get("stamina", 10),
					stats_obj.get("agility", 10),
					stats_obj.get("luck", 10),
					stats_obj.get("armor", 5),
					stats_obj.get("min_damage", 1),
					stats_obj.get("max_damage", 3)
				],
				"rank": arena_entry.get("rank", 0),  # Player rank from server
				"profession": 0,
				"blessing": 0,
				"potion": 0,
				"elixir": [],
				"bag_slots": [],
				"perks": [],
				"talents": []
			}
			arena_data.append(player_data)
		
		# Merge arena opponents into enemy_players (overwrite duplicates)
		_merge_arena_into_enemies(arena_data)
	
	# Load chat messages if available (new format: local_chat and global_chat arrays)
	chat_messages.clear()
	if char_data.has("local_chat") and char_data.local_chat is Array:
		_load_chat_array(char_data.local_chat, "local")
	if char_data.has("global_chat") and char_data.global_chat is Array:
		_load_chat_array(char_data.global_chat, "global")

func _merge_arena_into_enemies(arena_data: Array):
	"""Merge arena opponents into enemy_players, overwriting any duplicates"""
	for arena_player_data in arena_data:
		var character_id = arena_player_data.get("character_id", 0)
		
		# Find if this character already exists in enemy_players
		var existing_index = -1
		for i in range(enemy_players.size()):
			if enemy_players[i].character_id == character_id:
				existing_index = i
				break
		
		var arena_player = GamePlayer.new(arena_player_data, self)
		
		if existing_index >= 0:
			# Overwrite existing entry with more complete arena data
			enemy_players[existing_index] = arena_player
		else:
			# Add new arena opponent
			enemy_players.append(arena_player)
	
	# Update rankings after merging
	update_rankings()

# ============================================
# WORLD DATA LOADING
# ============================================
func load_enemy_players_data(players_data: Array):
	enemy_players.clear()
	for player_data in players_data:
		var player = GamePlayer.new(player_data, self)
		enemy_players.append(player)
	update_rankings()

func _load_chat_array(messages_data: Array, chat_type: String):
	"""Load chat messages from server array (new format with character_name, timestamp as int)"""
	for message_data in messages_data:
		# Transform server format to ChatMessage format
		# Server: {id, character_name, lobby_id, message, timestamp (unix int)}
		# ChatMessage: {sender, timestamp (ISO string), status, message, type}
		var chat_data = {
			"sender": message_data.get("character_name", "Unknown"),
			"message": message_data.get("message", ""),
			"timestamp": _unix_to_iso(message_data.get("timestamp", 0)),
			"type": chat_type,
			"status": "peasant"  # TODO: Get from server if available
		}
		chat_messages.append(ChatMessage.new(chat_data))

func _unix_to_iso(unix_timestamp: int) -> String:
	"""Convert Unix timestamp to ISO 8601 format"""
	if unix_timestamp == 0:
		return ""
	var datetime = Time.get_datetime_dict_from_unix_time(unix_timestamp)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

func load_chat_messages_data(messages_data: Array):
	"""Legacy: Load chat messages (old format)"""
	chat_messages.clear()
	for message_data in messages_data:
		chat_messages.append(ChatMessage.new(message_data))

func update_rankings():
	"""Build unified rankings list: enemy_players + current_player"""
	rankings_players.clear()
	
	if not current_player:
		# No current player, just copy enemy_players
		for player in enemy_players:
			rankings_players.append(player)
		return
	
	# Build rankings list from enemy_players (skip any with same character_id as current_player)
	for player in enemy_players:
		if player.character_id != current_player.character_id:
			rankings_players.append(player)
	
	# Always add current_player
	rankings_players.append(current_player)
	
	# Sort by rank (ascending - rank 1 first)
	rankings_players.sort_custom(func(a, b): return a.rank < b.rank)
	

func apply_combat_header_updates(combat: CombatResponse):
	"""Apply optional header-level combat results (honor, etc.) to runtime player lists."""
	if combat == null:
		return

	var changed := false

	# Update current player honor when server sends it.
	if current_player and combat.player_id == current_player.character_id and combat.player_honor >= 0:
		if current_player.honor != combat.player_honor:
			current_player.honor = combat.player_honor
			changed = true

	# Update enemy players honor for both combat participants when available.
	for player in enemy_players:
		if player.character_id == combat.player_id and combat.player_honor >= 0 and player.honor != combat.player_honor:
			player.honor = combat.player_honor
			changed = true
		if player.character_id == combat.enemy_id and combat.enemy_honor >= 0 and player.honor != combat.enemy_honor:
			player.honor = combat.enemy_honor
			changed = true

	if changed:
		# Recompute local ranks from honor so impacted players move in the leaderboard.
		_reorder_rankings_by_honor()
		if UIManager.instance:
			if UIManager.instance.rankings_panel and UIManager.instance.rankings_panel.visible and UIManager.instance.rankings_panel.has_method("populate_rankings"):
				UIManager.instance.rankings_panel.populate_rankings()
			if UIManager.instance.arena_panel and UIManager.instance.arena_panel.visible and UIManager.instance.arena_panel.has_method("_load_opponent_data"):
				UIManager.instance.arena_panel._load_opponent_data()

func _reorder_rankings_by_honor():
	"""Recompute rankings_players ordering by honor desc and reassign ranks
	using the existing rank numbers in the local list, so impacted players
	swap positions immediately after a combat result."""
	update_rankings()
	if rankings_players.is_empty():
		return

	var existing_ranks: Array = []
	for p in rankings_players:
		existing_ranks.append(p.rank)
	existing_ranks.sort()

	rankings_players.sort_custom(func(a, b): return a.honor > b.honor)

	for i in range(rankings_players.size()):
		rankings_players[i].rank = int(existing_ranks[i])

# ============================================
# QUEST MANAGEMENT
# ============================================
func get_quest_clicked_options(quest_id: int) -> Array[int]:
	var clicked_options: Array[int] = []
	if not current_player:
		return clicked_options

	for entry in current_player.quest_log:
		if not (entry is Dictionary):
			continue
		if int(entry.get("quest_id", 0)) != quest_id:
			continue
		var option_id = int(entry.get("option_id", 0))
		if option_id <= 0:
			continue
		clicked_options.append(option_id)


	return clicked_options

func get_last_quest_option_id(quest_id: int) -> int:
	if not current_player:
		return 0

	for i in range(current_player.quest_log.size() - 1, -1, -1):
		var entry = current_player.quest_log[i]
		if not (entry is Dictionary):
			continue
		if int(entry.get("quest_id", 0)) != quest_id:
			continue
		var option_id = int(entry.get("option_id", 0))
		if option_id > 0:
			return option_id

	return 0

func append_quest_log_action(quest_id: int, option_id: int, finished: bool = false):
	if not current_player or quest_id <= 0:
		return
	if option_id <= 0 and not finished:
		return

	var entry = {
		"quest_id": int(quest_id),
		"option_id": int(option_id),
		"finished": bool(finished)
	}
	current_player.quest_log.append(entry)

func complete_quest(quest_id: int, clicked_options: Array[int] = [], remove_from_daily: bool = true):
	if not current_player:
		return
	
	# Remove from daily quests so it no longer shows in the village
	if remove_from_daily:
		current_player.daily_quests.erase(quest_id)

	var last_option_id = 0
	if clicked_options.size() > 0:
		last_option_id = int(clicked_options[clicked_options.size() - 1])
	else:
		last_option_id = get_last_quest_option_id(quest_id)

	append_quest_log_action(quest_id, last_option_id, true)
	quest_completed.emit(quest_id)
