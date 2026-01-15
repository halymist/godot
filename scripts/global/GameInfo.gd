extends Node

# Persistent game data manager - AutoLoad
# This holds all player data permanently, separate from UI

# ============================================
# DATABASE REFERENCES
# ============================================
var effects_db: EffectDatabase = null
var items_db: ItemDatabase = null
var perks_db: PerkDatabase = null
var npcs_db: NpcDatabase = null
var cosmetics_db: CosmeticDatabase = null
var settlements_db: SettlementsDatabase = null
var quests_db: QuestsDatabase = null
var enemies_db: EnemyDatabase = null

# ============================================
# RUNTIME DATA
# ============================================
# Character management
var all_characters: Array[GameCurrentPlayer] = []
var current_character_id: int = 0

# World data (populated per character)
var enemy_players: Array[GamePlayer] = []
var rankings_players: Array[GamePlayer] = []  # Unified list: enemy_players + current_player (no duplicates)
var arena_opponents: Array[int] = []
var chat_messages: Array[ChatMessage] = []
var current_combat_log: CombatResponse = null

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

func _ready():
	print("GameInfo initialized (databases not loaded yet)")

func load_databases():
	"""Call this from lobby scene to load all game databases"""
	if databases_loaded:
		return  # Already loaded
	
	print("Loading databases...")
	effects_db = load("res://data/effects.tres")
	items_db = load("res://data/items.tres")
	perks_db = load("res://data/perks.tres")
	npcs_db = load("res://data/npcs.tres")
	cosmetics_db = load("res://data/cosmetics.tres")
	quests_db = load("res://scripts/resources/quests.tres")
	settlements_db = load("res://scripts/resources/settlements.tres")
	enemies_db = load("res://data/enemies.tres")
	
	databases_loaded = true
	print("Databases loaded")

# ============================================
# TALENT REGISTRATION
# ============================================
func register_talent(id: int, effect_id: int, factor: float, max_points: int, perk_slot: int = 0):
	talent_registry[id] = {
		"effect_id": effect_id,
		"factor": factor,
		"max_points": max_points,
		"perk_slot": perk_slot
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
	
	# Client-side cache (not serialized)
	var texture: Texture2D = null
	var _resource_cache: ItemResource = null
	
	func _init(data: Dictionary = {}):
		# Simple direct assignment
		for key in data:
			if key in self:
				set(key, data[key])
		
		# Cache texture for performance
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
		
		# Get perk data from perks_db if available
		if GameInfo and GameInfo.perks_db:
			var perk_resource = GameInfo.perks_db.get_perk_by_id(id)
			if perk_resource:
				# Copy static data from resource
				perk_name = perk_resource.perk_name
				effect1_id = perk_resource.effect1_id
				factor1 = perk_resource.factor1
				effect2_id = perk_resource.effect2_id
				factor2 = perk_resource.factor2
				texture = perk_resource.icon
				
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
	
	var player: int = 1  # 1 = player, 2 = enemy
	var action: String = ""
	var factor: int = 0  # Optional damage/heal amount
	
	func _init(data: Dictionary = {}):
		# Simple direct assignment
		for key in data:
			if key in self:
				set(key, data[key])

class CombatResponse:
	extends RefCounted
	
	var player1_name: String = ""
	var player1_health: int = 0
	var player1_avatar: Array = [1, 10, 20, 30, 40]  # [face, hair, eyes, nose, mouth]
	var player2_name: String = ""
	var player2_health: int = 0
	var player2_avatar: Array = [1, 11, 21, 31, 41]  # [face, hair, eyes, nose, mouth]
	var enemyid: int = 0  # If > 0, enemy is NPC (lookup in enemies_db), otherwise player vs player
	var haswon: bool = false  # True if player1 won, false if player1 lost
	var combat_log: Array[CombatLogEntry] = []
	
	func _init(data: Dictionary = {}):
		# Load simple properties (excluding combat_log)
		for key in data:
			if key in self and key not in ["logs", "combat_log"]:
				set(key, data[key])
		
		# Handle combat_log/logs array specially
		var logs_data = data.get("logs", data.get("combat_log", []))
		if logs_data:
			combat_log.clear()
			for log_data in logs_data:
				combat_log.append(CombatLogEntry.new(log_data))
		
		# Handle alternate field names from server
		if data.has("player1name"):
			player1_name = data["player1name"]
		if data.has("player1health"):
			player1_health = data["player1health"]
		if data.has("player2name"):
			player2_name = data["player2name"]
		if data.has("player2health"):
			player2_health = data["player2health"]

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
	var avatar_face: int = 1
	var avatar_hair: int = 10
	var avatar_eyes: int = 20
	var avatar_nose: int = 30
	var avatar_mouth: int = 40
	var blessing: int = 0  # Active blessing effect ID (0 = no blessing)
	var potion: int = 0  # Equipped potion item ID (0 = no potion)
	var elixir: int = 0  # Equipped elixir item ID (0 = no elixir)
	var bag_slots: Array[Item] = []
	var perks: Array[Perk] = []
	var talents: Array[Talent] = []
	
	func _init(data: Dictionary = {}, game_info: GameInfo = null):
		game_info_ref = game_info
		
		# Load simple properties (excluding arrays and special cases)
		for key in data:
			if key in self and key not in ["avatar", "stats", "bag_slots", "perks", "talents"]:
				set(key, data[key])
		
		# Handle avatar array [face, hair, eyes, nose, mouth]
		if data.has("avatar") and data.avatar.size() >= 5:
			avatar_face = data.avatar[0]
			avatar_hair = data.avatar[1]
			avatar_eyes = data.avatar[2]
			avatar_nose = data.avatar[3]
			avatar_mouth = data.avatar[4]
		
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
	
	func get_total_stats() -> Dictionary:
		"""Calculate total stats: base + equipped items (including gems) + effect bonuses"""
		var total_stats = get_base_stats()
		
		# Add stats from equipped items (slots 0-9)
		for item in bag_slots:
			if item.bag_slot_id >= 0 and item.bag_slot_id < 10:
				# Item stats (already scaled by day/tempered)
				total_stats.strength += item.strength
				total_stats.stamina += item.stamina
				total_stats.agility += item.agility
				total_stats.luck += item.luck
				total_stats.armor += item.armor
				total_stats.damage_min += item.damage_min
				total_stats.damage_max += item.damage_max
				
				# Add socketed gem stats (gem is just another item!)
				var gem = item.get_socketed_gem()
				if gem:
					total_stats.strength += gem.strength
					total_stats.stamina += gem.stamina
					total_stats.agility += gem.agility
					total_stats.luck += gem.luck
					total_stats.armor += gem.armor
					total_stats.damage_min += gem.damage_min
					total_stats.damage_max += gem.damage_max
		
		# Apply effect bonuses to stats (effects 1-4 boost stats by percentage)
		var total_effects = get_total_effects()
		total_stats.strength = int(round(total_stats.strength * (1.0 + total_effects[1] / 100.0)))
		total_stats.stamina = int(round(total_stats.stamina * (1.0 + total_effects[2] / 100.0)))
		total_stats.agility = int(round(total_stats.agility * (1.0 + total_effects[3] / 100.0)))
		total_stats.luck = int(round(total_stats.luck * (1.0 + total_effects[4] / 100.0)))
		
		return total_stats
	
	func get_total_effects() -> Dictionary:
		# Initialize effect totals for all 20 effects (IDs 1-20)
		var total_effects = {}
		for i in range(1, 21):
			total_effects[i] = 0.0
		
		# 1. Sum effects from equipped items (slots 0-9)
		for item in bag_slots:
			if item.bag_slot_id >= 0 and item.bag_slot_id < 10:
				if item.effect_id > 0 and item.effect_id <= 20:
					total_effects[item.effect_id] += item.effect_factor
		
		# 2. Add potion effect (if property exists in subclass)
		if "potion" in self and self.potion > 0 and GameInfo and GameInfo.items_db:
			var potion_item = GameInfo.items_db.get_item_by_id(self.potion)
			if potion_item and potion_item.effect_id > 0 and potion_item.effect_id <= 20:
				total_effects[potion_item.effect_id] += potion_item.effect_factor
		
		# 3. Add blessing effect (if property exists in subclass)
		if "blessing" in self and self.blessing > 0 and GameInfo and GameInfo.perks_db:
			var blessing_perk = GameInfo.perks_db.get_perk_by_id(self.blessing)
			if blessing_perk and blessing_perk.effect1_id > 0 and blessing_perk.effect1_id <= 20:
				total_effects[blessing_perk.effect1_id] += blessing_perk.factor1
		
		# 4. Add active perks effects
		var active_perks = get_active_perks()
		for perk in active_perks:
			# Effect 1
			if perk.effect1_id > 0 and perk.effect1_id <= 20:
				total_effects[perk.effect1_id] += perk.factor1
			# Effect 2
			if perk.effect2_id > 0 and perk.effect2_id <= 20:
				total_effects[perk.effect2_id] += perk.factor2
		
		# 5. Add elixir effects (decode ID and sum ingredient effects) (if property exists in subclass)
		if "elixir" in self and self.elixir > 0 and GameInfo and GameInfo.items_db:
			var id_str = str(self.elixir)
			if id_str.length() >= 13:  # Format: 1000XXXYYYZZZZ
				var ingredient1_id = int(id_str.substr(4, 3))
				var ingredient2_id = int(id_str.substr(7, 3))
				var ingredient3_id = int(id_str.substr(10, 3))
				
				for ingredient_id in [ingredient1_id, ingredient2_id, ingredient3_id]:
					if ingredient_id > 0:
						var ingredient = GameInfo.items_db.get_item_by_id(ingredient_id)
						if ingredient and ingredient.effect_id > 0 and ingredient.effect_id <= 20:
							total_effects[ingredient.effect_id] += ingredient.effect_factor
		
		# 6. Add talents effects (from runtime registry populated by Talent.gd nodes)
		for talent in talents:
			var talent_id = talent.talent_id
			var points_spent = talent.points
			
			# Look up metadata from registry
			if talent_id in GameInfo.talent_registry:
				var talent_meta = GameInfo.talent_registry[talent_id]
				
				# Skip perk slot talents (they don't provide direct effects)
				if talent_meta.perk_slot > 0:
					continue
				
				# Calculate talent contribution
				if talent_meta.effect_id > 0 and talent_meta.effect_id <= 20:
					var talent_effect = points_spent * talent_meta.factor
					total_effects[talent_meta.effect_id] += talent_effect
		
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
	var destination: Variant = null
	var slide: Variant = null
	var slides: Array = []
	var talent_points: int = 0
	var quest_log: Array = []  # Array of {quest_id: int, status: String} to track quest completion
	var daily_quests: Array[int] = []  # Array of quest IDs available today
	var server_timezone: String = "UTC"  # Server's timezone (e.g., "Europe/Stockholm")
	var server_day: int = 1  # Current day on the server (starts at 1)
	var weather: int = 1  # Weather condition (1=sunny, 2=rainy)
	
	# VIP status
	var vip: bool = false
	var autoskip: bool = false  # VIP only - skip travel screen and go directly to quest
	
	# Silver (no automatic emission - use UIManager.update_display())
	var silver: int = 0
	
	# Mushrooms with automatic event emission
	var _mushrooms: int = 0
	var mushrooms: int:
		get: return _mushrooms
		set(value):
			_mushrooms = value
	
	func _init(data: Dictionary = {}, game_info: GameInfo = null):
		# Call parent constructor with data
		super._init(data, game_info)
		
		# Load current player specific fields (excluding special cases)
		for key in data:
			if key in self and key not in ["daily_quests", "mushrooms", "avatar", "stats", "bag_slots", "perks", "talents"]:
				set(key, data[key])
		
		# Handle daily_quests array with type conversion
		if data.has("daily_quests"):
			daily_quests.clear()
			for quest_id in data.daily_quests:
				daily_quests.append(quest_id as int)
		
		# Handle mushrooms to trigger setter
		if data.has("mushrooms"):
			mushrooms = data.mushrooms
		
		# Convert null traveling to 0
		if traveling == null:
			traveling = 0
		
	
	func get_player_stats() -> Dictionary:
		var stats = get_total_stats()
		stats["silver"] = silver
		stats["mushrooms"] = mushrooms
		stats["talent_points"] = talent_points
		return stats

func load_all_characters(characters_data: Array):
	all_characters.clear()
	for char_data in characters_data:
		var player = GameCurrentPlayer.new(char_data, self)
		all_characters.append(player)
	print("Loaded ", all_characters.size(), " characters")

func select_character(character_id: int):
	current_character_id = character_id
	
	if current_player:
		print("Selected character: ", current_player.name, " (ID: ", character_id, ")")
		_load_character_world_data()
	else:
		print("ERROR: Character ID ", character_id, " not found!")

func _load_character_world_data():
	var char_data: Dictionary = {}
	for character in Websocket.mock_characters:
		if character.character_id == current_character_id:
			char_data = character
			break
	
	if char_data.is_empty():
		print("ERROR: Could not find character data for ID ", current_character_id)
		return
	
	load_enemy_players_data(char_data.rankings)
	load_chat_messages_data(char_data.chat_messages)
	
	if char_data.has("arena_opponents") and char_data.arena_opponents is Array:
		arena_opponents.assign(char_data.arena_opponents)
		print("Loaded ", arena_opponents.size(), " arena opponents")

# ============================================
# WORLD DATA LOADING
# ============================================
func load_enemy_players_data(players_data: Array):
	enemy_players.clear()
	for player_data in players_data:
		var player = GamePlayer.new(player_data, self)
		enemy_players.append(player)
	print("Loaded ", enemy_players.size(), " enemy players")
	update_rankings()

func load_chat_messages_data(messages_data: Array):
	chat_messages.clear()
	for message_data in messages_data:
		chat_messages.append(ChatMessage.new(message_data))
	print("Loaded ", chat_messages.size(), " chat messages")

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
	
	# Sort by honor (highest to lowest)
	rankings_players.sort_custom(func(a, b): return a.honor > b.honor)
	
	print("Rankings updated: ", rankings_players.size(), " players (current player included)")

# ============================================
# QUEST MANAGEMENT
# ============================================
func complete_quest(quest_id: int, clicked_options: Array[int] = []):
	if not current_player:
		return
	
	for entry in current_player.quest_log:
		if entry.get("quest_id") == quest_id:
			entry["finished"] = true
			entry["clicked_options"] = clicked_options
			quest_completed.emit(quest_id)
			return
	
	current_player.quest_log.append({
		"quest_id": quest_id,
		"clicked_options": clicked_options,
		"finished": true
	})
	quest_completed.emit(quest_id)
