extends Node
@export var fallback_folder: String = "res://assets/images/fallback"
# Persistent game data manager - AutoLoad
# This holds all player data permanently, separate from UI

# Static game data
var effects_db: EffectDatabase = null
var items_db: ItemDatabase = null
var perks_db: PerkDatabase = null
var npcs_db: NpcDatabase = null
var cosmetics_db: CosmeticDatabase = null
var settlements_db: SettlementsDatabase = null
var quests_db: QuestsDatabase = null
var enemies_db: EnemyDatabase = null

# Runtime talent registry (populated by Talent.gd nodes on _ready)
var talent_registry: Dictionary = {}  # {talent_id: {effect_id, factor, max_points, perk_slot}}

# Village names mapping
const VILLAGE_NAMES = {
	1: "Krasna Ves",
	2: "Katusice",
	3: "Horni Dvur",
	4: "Dolni Ves",
	5: "Stary Mlyn"
}

func get_village_name(location_id: int) -> String:
	"""Get the village name for a given location ID"""
	return VILLAGE_NAMES.get(location_id, "Unknown Village")

func get_location_data(location_id: int) -> LocationResource:
	"""Get the location data for a given location ID"""
	if settlements_db:
		return settlements_db.get_location_by_id(location_id)
	return null

func register_talent(id: int, effect_id: int, factor: float, max_points: int, perk_slot: int = 0):
	"""Called by Talent.gd nodes on _ready() to register their metadata"""
	talent_registry[id] = {
		"effect_id": effect_id,
		"factor": factor,
		"max_points": max_points,
		"perk_slot": perk_slot
	}
	print("Registered talent %d: effect=%d, factor=%.1f, max_points=%d, perk_slot=%d" % [id, effect_id, factor, max_points, perk_slot])

# Faction names mapping
const FACTION_DATA = {
	1: {"name": "Order"},
	2: {"name": "Guild"},
	3: {"name": "Companions"}
}

func get_faction_name(faction_id: int) -> String:
	"""Get the faction name for a given faction ID"""
	var data = FACTION_DATA.get(faction_id, {})
	return data.get("name", "None")

# Profession names and icons mapping
const PROFESSION_DATA = {
	1: {"name": "Herbalist", "icon": "res://assets/images/ui/merchant.png"},
	2: {"name": "Blacksmith", "icon": "res://assets/images/ui/merchant.png"},
	3: {"name": "Enchanter", "icon": "res://assets/images/ui/merchant.png"},
	4: {"name": "Warrior", "icon": "res://assets/images/ui/merchant.png"}
}

func get_profession_name(profession_id: int) -> String:
	"""Get the profession name for a given profession ID"""
	var data = PROFESSION_DATA.get(profession_id, {})
	return data.get("name", "None")

func get_profession_icon(profession_id: int) -> String:
	"""Get the profession icon path for a given profession ID"""
	var data = PROFESSION_DATA.get(profession_id, {})
	return data.get("icon", "")

# Signals for UI updates
signal on_player_data_loaded
signal current_panel_changed(new_panel)
signal current_panel_overlay_changed(new_overlay) # panels that partially cover the screen
signal quest_completed(quest_id) # Emitted when a quest is marked as completed
signal rankings_loaded # Emitted when rankings data is loaded

# Inner Classes - Single source of truth

# Base class with shared MessagePack functionality
class MessagePackObject:
	extends RefCounted
	
	# Generic MessagePack loader - override MSGPACK_MAP in child classes
	func _init(data: Dictionary = {}):
		if not data.is_empty():
			load_from_msgpack(data)
	
	func load_from_msgpack(data: Dictionary):
		var msgpack_map = get("MSGPACK_MAP")
		if msgpack_map:
			for msgpack_key in msgpack_map:
				var local_key = msgpack_map[msgpack_key]
				if data.has(msgpack_key):
					set(local_key, data[msgpack_key])
				# Silently skip missing keys - they're optional fields
	
	func to_msgpack() -> Dictionary:
		var result = {}
		var msgpack_map = get("MSGPACK_MAP")
		if msgpack_map:
			for msgpack_key in msgpack_map:
				var local_key = msgpack_map[msgpack_key]
				result[msgpack_key] = get(local_key)
		return result

class Item:
	extends MessagePackObject
	
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
	
	# MessagePack field mapping
	const MSGPACK_MAP = {
		"id": "id",
		"bag_slot_id": "bag_slot_id",
		"day": "day",
		"effect_overdrive": "effect_overdrive",
		"tempered": "tempered",
		"socket_id": "socket_id",
		"socket_day": "socket_day"
	}
	
	func _init(data: Dictionary = {}):
		super._init(data)
		# Cache texture for performance
		if GameInfo and GameInfo.items_db:
			var res = get_resource()
			if res:
				texture = res.icon
	
	# Helper to get ItemResource (cached)
	func get_resource() -> ItemResource:
		if not _resource_cache and GameInfo and GameInfo.items_db:
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
	
	# Centralized stat calculation function - used by Item properties, previews, and displays
	# Tempering is a separate 10% multiplicative bonus on top of day scaling
	func calculate_scaled_stat(base_value: int, day_value: int, tempered_value: int) -> int:
		if base_value == 0:
			return 0
		
		# First, apply day scaling and round
		var result = float(base_value)
		if day_value > 0:
			result = result * pow(1.02, day_value)
		result = round(result)
		
		# Then apply tempering bonus iteratively (10% per level with rounding at each step)
		# This ensures each tempering level applies 10% to the current rounded value
		for i in range(tempered_value):
			result = round(result * 1.1)
		
		return int(result)
	
	# Base stats from ItemResource (before modifications)
	func _get_base_stat(stat_name: String) -> int:
		var res = get_resource()
		if not res:
			return 0
		var base = res.get(stat_name)
		if base == null:
			return 0
		
		return calculate_scaled_stat(base, day, tempered)
	
	# Stat properties with scaling applied
	var strength: int:
		get: return _get_base_stat("strength")
	
	var stamina: int:
		get: return _get_base_stat("stamina")
	
	var agility: int:
		get: return _get_base_stat("agility")
	
	var luck: int:
		get: return _get_base_stat("luck")
	
	var armor: int:
		get: return _get_base_stat("armor")
	
	var damage_min: int:
		get: return _get_base_stat("damage_min")
	
	var damage_max: int:
		get: return _get_base_stat("damage_max")
	
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
	
	# Legacy aliases for renamed fields
	var enchant_overdrive: int:
		get: return effect_overdrive
		set(value): effect_overdrive = value
	
	var socketed_gem_id: int:
		get: return socket_id
		set(value): socket_id = value
	
	var socketed_gem_day: int:
		get: return socket_day
		set(value): socket_day = value
	
	func get_socketed_gem() -> ItemResource:
		"""Get the socketed gem's ItemResource if one exists"""
		if socket_id > 0 and GameInfo and GameInfo.items_db:
			return GameInfo.items_db.get_item_by_id(socket_id)
		return null
	
	func get_base_stats_without_gem() -> Dictionary:
		"""Get item stats excluding socketed gem bonuses"""
		return {
			"strength": strength,
			"stamina": stamina,
			"agility": agility,
			"luck": luck,
			"armor": armor
		}
	
	func get_gem_stats() -> Dictionary:
		"""Get stats from socketed gem with day scaling applied"""
		var gem = get_socketed_gem()
		if gem:
			# Apply day-based scaling to gem stats (2% improvement per day)
			var gem_strength = gem.strength
			var gem_stamina = gem.stamina
			var gem_agility = gem.agility
			var gem_luck = gem.luck
			var gem_armor = gem.armor
			
			if socketed_gem_day > 0:
				var day_multiplier = pow(1.02, socketed_gem_day)
				gem_strength = int(ceil(gem_strength * day_multiplier))
				gem_stamina = int(ceil(gem_stamina * day_multiplier))
				gem_agility = int(ceil(gem_agility * day_multiplier))
				gem_luck = int(ceil(gem_luck * day_multiplier))
				gem_armor = int(ceil(gem_armor * day_multiplier))
			else:
				gem_strength = int(gem_strength)
				gem_stamina = int(gem_stamina)
				gem_agility = int(gem_agility)
				gem_luck = int(gem_luck)
				gem_armor = int(gem_armor)
			
			return {
				"strength": gem_strength,
				"stamina": gem_stamina,
				"agility": gem_agility,
				"luck": gem_luck,
				"armor": gem_armor
			}
		return {
			"strength": 0,
			"stamina": 0,
			"agility": 0,
			"luck": 0,
			"armor": 0
		}

class Perk:
	extends MessagePackObject
	
	# MessagePack properties (only dynamic data from server)
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
	
	# MessagePack field mapping - id, active, and slot from server
	const MSGPACK_MAP = {
		"id": "id",
		"active": "active",
		"slot": "slot"
	}
	
	func _init(data: Dictionary = {}):
		super._init(data)
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
	extends MessagePackObject
	
	# MessagePack properties matching C# Talent class
	var talent_id: int = 0
	var points: int = 0
	
	const MSGPACK_MAP = {
		"talent_id": "talent_id",
		"points": "points"
	}

# Ranking Entry for lightweight rankings display
# RankingEntry class removed - now using full GamePlayer data in enemy_players array
# Rankings panel will reference enemy_players[rankings_indices[i]]

class ChatMessage:
	extends MessagePackObject
	
	# Chat message properties
	var sender: String = ""
	var timestamp: String = ""
	var status: String = "peasant"  # "peasant" or "lord"
	var message: String = ""
	var type: String = "global"  # "global" or "local"
	
	const MSGPACK_MAP = {
		"sender": "sender",
		"timestamp": "timestamp", 
		"status": "status",
		"message": "message",
		"type": "type"
	}

class CombatLogEntry:
	extends MessagePackObject
	
	var player: int = 1  # 1 = player, 2 = enemy
	var action: String = ""
	var factor: int = 0  # Optional damage/heal amount
	
	const MSGPACK_MAP = {
		"player": "player",
		"action": "action",
		"factor": "factor"
	}

class CombatResponse:
	extends MessagePackObject
	
	var player1_name: String = ""
	var player1_health: int = 0
	var player1_avatar: Array = [1, 10, 20, 30, 40]  # [face, hair, eyes, nose, mouth]
	var player2_name: String = ""
	var player2_health: int = 0
	var player2_avatar: Array = [1, 11, 21, 31, 41]  # [face, hair, eyes, nose, mouth]
	var enemyid: int = 0  # If > 0, enemy is NPC (lookup in enemies_db), otherwise player vs player
	var haswon: bool = false  # True if player1 won, false if player1 lost
	var combat_log: Array[CombatLogEntry] = []
	
	const MSGPACK_MAP = {
		"player1name": "player1_name",
		"player1health": "player1_health",
		"player1_avatar": "player1_avatar",
		"player2name": "player2_name", 
		"player2health": "player2_health",
		"player2_avatar": "player2_avatar",
		"enemyid": "enemyid",
		"haswon": "haswon",
		"logs": "combat_log"
	}
	
	func _init(data: Dictionary = {}):
		super._init(data)
		# Handle the combat log array specially
		if data.has("logs"):
			combat_log.clear()
			for log_data in data["logs"]:
				combat_log.append(CombatLogEntry.new(log_data))

class GamePlayer:
	extends MessagePackObject
	
	# Events/Signals reference (for emitting from CurrentPlayer)
	var game_info_ref: GameInfo
	
	# Base properties shared by all players
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
	
	# Base MessagePack fields shared by all players
	const MSGPACK_MAP = {
		"name": "name",
		"rank": "rank",
		"faction": "faction",
		"profession": "profession",
		"honor": "honor",
		"strength": "strength",
		"stamina": "stamina",
		"agility": "agility",
		"luck": "luck",
		"armor": "armor",
		"avatar_face": "avatar_face",
		"avatar_hair": "avatar_hair",
		"avatar_eyes": "avatar_eyes",
		"avatar_nose": "avatar_nose",
		"avatar_mouth": "avatar_mouth",
		"blessing": "blessing",
		"potion": "potion",
		"elixir": "elixir"
	}
	
	func _init(data: Dictionary = {}, game_info: GameInfo = null):
		game_info_ref = game_info
		super._init(data)
	
	func load_from_msgpack(data: Dictionary):
		# Load base stats using parent functionality
		super.load_from_msgpack(data)
		
		# Load arrays
		load_bag_slots(data)
		load_perks(data)
		load_talents(data)
	
	func load_bag_slots(data: Dictionary):
		bag_slots.clear()
		var items_data = data.get("bag_slots", [])
		print("Loading bag_slots: ", items_data.size(), " items found")
		for item_data in items_data:
			var item = Item.new(item_data)
			print("  Loaded item: ", item.item_name, " at slot ", item.bag_slot_id)
			bag_slots.append(item)
	
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
			"armor": armor
		}
	
	func get_total_stats() -> Dictionary:
		var total_stats = get_base_stats()
		
		# Add stats from equipped items (slots 0-9)
		for item in bag_slots:
			if item.bag_slot_id >= 0 and item.bag_slot_id < 10:
				total_stats.strength += item.strength
				total_stats.stamina += item.stamina
				total_stats.agility += item.agility
				total_stats.luck += item.luck
				total_stats.armor += item.armor
				
				# Add stats from socketed gems
				var gem_stats = item.get_gem_stats()
				total_stats.strength += gem_stats.strength
				total_stats.stamina += gem_stats.stamina
				total_stats.agility += gem_stats.agility
				total_stats.luck += gem_stats.luck
				total_stats.armor += gem_stats.armor
		
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
	
	func get_profession_name() -> String:
		match profession:
			1: return "Herbalist"
			2: return "Blacksmith"
			3: return "Enchanter"
			4: return "Warrior"
			_: return "None"

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
	var daily_quests: Array = []  # Array of quest IDs available today
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
	
	# Extended MessagePack mapping (includes base + current player fields)
	const CURRENT_PLAYER_MSGPACK_MAP = {
		# Current player specific fields (base fields handled by parent class)
		"location": "location",
		"traveling": "traveling",
		"traveling_destination": "traveling_destination",
		"silver": "silver",
		"mushrooms": "_mushrooms",  # Use private field to avoid triggering setter
		"talent_points": "talent_points",
		"dungeon": "dungeon",
		"destination": "destination",
		"slide": "slide",
		"slides": "slides",
		"quest_log": "quest_log",
		"daily_quests": "daily_quests",
		"server_timezone": "server_timezone",
		"server_day": "server_day",
		"weather": "weather",
		"vip": "vip",
		"autoskip": "autoskip"
	}
	
	func load_from_msgpack(data: Dictionary):
		# Load base fields first (from GamePlayer.MSGPACK_MAP)
		for msgpack_key in GamePlayer.MSGPACK_MAP:
			if data.has(msgpack_key):
				var local_key = GamePlayer.MSGPACK_MAP[msgpack_key]
				set(local_key, data[msgpack_key])
		
		# Load current player specific fields
		var msgpack_map = CURRENT_PLAYER_MSGPACK_MAP
		for msgpack_key in msgpack_map:
			if data.has(msgpack_key):
				var local_key = msgpack_map[msgpack_key]
				var value = data[msgpack_key]
				
				# Special handling for traveling: convert null to 0
				if msgpack_key == "traveling" and value == null:
					value = 0
				
				set(local_key, value)
		
		# Load arrays
		load_bag_slots(data)
		load_perks(data)
		load_talents(data)
		
		# Trigger property setter for mushrooms to emit signal
		mushrooms = _mushrooms
		
	
	func get_player_stats() -> Dictionary:
		var stats = get_total_stats()
		stats["silver"] = silver
		stats["mushrooms"] = mushrooms
		stats["talent_points"] = talent_points
		return stats

# GameInfo main class properties
var current_player: GameCurrentPlayer
var enemy_players: Array[GamePlayer] = []  # Unified array for all enemy player data
var current_arena_opponent: String = ""  # Name of current opponent (references enemy_players by name)
var arena_opponents: Array[String] = []  # Array of player names for arena selection
var chat_messages: Array[ChatMessage] = []
var combat_logs: Array[CombatResponse] = []
var current_combat_log: CombatResponse = null
var npcs: Array[Dictionary] = []
var vendor_items: Array[Item] = []
var rankings_indices: Array[int] = []  # Indices into enemy_players array (ordered by rank)

# Panel tracking for navigation (where the client currently is)
var current_panel: Control = null:
	set(value):
		current_panel = value
		current_panel_changed.emit(value)

var current_panel_overlay: Control = null:
	set(value):
		current_panel_overlay = value
		current_panel_overlay_changed.emit(value)

# Legacy properties for backward compatibility
var player_silver: int:
	get: return current_player.silver if current_player else 0
	set(value): 
		if current_player:
			current_player.silver = value

var player_mushrooms: int:
	get: return current_player.mushrooms if current_player else 0
	set(value):
		if current_player:
			current_player.mushrooms = value

func _ready():
	print("GameInfo ready!")
	# Load effects database first (items and perks reference these)
	effects_db = load("res://data/effects.tres")
	items_db = load("res://data/items.tres")
	perks_db = load("res://data/perks.tres")
	npcs_db = load("res://data/npcs.tres")
	cosmetics_db = load("res://data/cosmetics.tres")
	quests_db = load("res://scripts/resources/quests.tres")
	settlements_db = load("res://scripts/resources/settlements.tres")
	enemies_db = load("res://data/enemies.tres")
	
	load_player_data(Websocket.mock_character_data)
	load_enemy_players_data(Websocket.mock_rankings)  # Load all enemy players from rankings data
	load_chat_messages_data(Websocket.mock_chat_messages)
	load_arena_opponent_names(Websocket.mock_arena_opponents)  # Set arena opponents by name
	load_combat_logs_data(Websocket.mock_combat_logs)
	load_vendor_items_data(Websocket.mock_vendor_items)
	# NPCs are now client-side resources - loaded from npcs.tres based on daily_quests
	# Quest loading removed - will use quests.tres database instead
	set_current_combat_log(2)  # Set to wizard vs fire demon combat to show multi-action synchronization
	print_arena_opponents_info()

# Helper function to get player stats for UI
func get_player_stats() -> Dictionary:
	return current_player.get_player_stats() if current_player else {}

# Helper to get a texture for an asset_id from fallback folder
func get_fallback_texture(asset_id: int) -> Texture2D:
	var path = "%s/%d.png" % [fallback_folder, asset_id]
	if ResourceLoader.exists(path):
		return load(path)
	return null

# UI Panel management functions
func set_current_panel(panel: Control):
	current_panel = panel

func get_current_panel() -> Control:
	return current_panel

func set_current_panel_overlay(panel: Control):
	current_panel_overlay = panel

func get_current_panel_overlay() -> Control:
	return current_panel_overlay

# Load player data into current_player with automatic event emission
func load_player_data(character_data: Dictionary):
	print("Loading player data into GameInfo...")
	print("Raw character_data keys: ", character_data.keys())
	print("bag_slots in character_data: ", character_data.has("bag_slots"))
	if character_data.has("bag_slots"):
		print("bag_slots data: ", character_data["bag_slots"])
	
	current_player = GameCurrentPlayer.new(character_data, self)

	print("Player data loaded successfully!")
	print("Player: ", current_player.name)
	print("Silver: ", current_player.silver)
	print("Items: ", current_player.bag_slots.size())
	print("Perks: ", current_player.perks.size())
	print("Talents: ", current_player.talents.size())

	on_player_data_loaded.emit()

func get_total_stats() -> Dictionary:
	return current_player.get_total_stats() if current_player else {}

func get_total_effects() -> Dictionary:
	return current_player.get_total_effects() if current_player else {}

# Function to set current arena opponent by name
func set_arena_opponent(opponent_name: String):
	current_arena_opponent = opponent_name
	print("Arena opponent set to: ", opponent_name)

# Function to get current arena opponent data
func get_arena_opponent() -> GamePlayer:
	if current_arena_opponent.is_empty():
		return null
	for player in enemy_players:
		if player.name == current_arena_opponent:
			return player
	print("Warning: Current arena opponent '", current_arena_opponent, "' not found in enemy_players")
	return null

# Function to load all arena opponents from mock data
func load_enemy_players_data(players_data: Array):
	# Load all enemy player data into unified array
	enemy_players.clear()
	rankings_indices.clear()
	for i in range(players_data.size()):
		var player_data = players_data[i]
		var player = GamePlayer.new(player_data, self)
		enemy_players.append(player)
		rankings_indices.append(i)  # Rankings ordered by array index
		print("Loaded enemy player: ", player.name, " (Rank ", player.rank, ")")
	print("Total enemy players loaded: ", enemy_players.size())
	rankings_loaded.emit()

func load_arena_opponent_names(opponent_names: Array[String]):
	# Store arena opponent names for selection
	arena_opponents = opponent_names
	print("Setting arena opponents from names: ", arena_opponents)
	# Arena panel will look up players from enemy_players by name when needed

# Function to load chat messages from mock data
func load_chat_messages_data(messages_data: Array):
	chat_messages.clear()
	for message_data in messages_data:
		var chat_message = ChatMessage.new(message_data)
		chat_messages.append(chat_message)
	print("Total chat messages loaded: ", chat_messages.size())

# Function to load NPCs from mock data
func load_npcs_data(npcs_data: Array):
	npcs.clear()
	for npc_data in npcs_data:
		npcs.append(npc_data)
	print("Total NPCs loaded: ", npcs.size())

# Function to load combat logs from mock data
func load_combat_logs_data(combat_data: Array):
	combat_logs.clear()
	for combat_data_item in combat_data:
		var combat_response = CombatResponse.new(combat_data_item)
		combat_logs.append(combat_response)

# Function to load vendor items from mock data
# Function to load vendor items from mock data
func load_vendor_items_data(vendor_data: Array):
	vendor_items.clear()
	print("Loading vendor_items: ", vendor_data.size(), " items found")
	for item_id in vendor_data:
		var item = Item.new({
			"id": item_id,
			"day": current_player.server_day if current_player else 1  # Use current day for scaling
		})
		print("  Loaded vendor item: ", item.item_name, " (day ", item.day, ")")
		vendor_items.append(item)

# load_rankings_data removed - rankings now loaded via load_enemy_players_data

# Quest loading functions removed - will use quests.tres Resource database
# Old MessagePack quest loading (load_quest_slides_data, load_all_quests_data) removed

# Function to load quest log
func load_quest_log_data(quest_log_data: Array):
	if current_player:
		current_player.quest_log = quest_log_data.duplicate()
		print("Quest log loaded: ", current_player.quest_log.size(), " entries")

# Function to check if a quest is completed
func is_quest_completed(quest_id: int) -> bool:
	if not current_player:
		return false
	for entry in current_player.quest_log:
		if entry.get("quest_id") == quest_id and entry.get("finished") == true:
			return true
	return false

# Function to mark a quest as completed
func complete_quest(quest_id: int):
	if not current_player:
		return
	
	# Check if already in log
	for entry in current_player.quest_log:
		if entry.get("quest_id") == quest_id:
			entry["finished"] = true
			print("Quest ", quest_id, " marked as finished")
			quest_completed.emit(quest_id)
			return
	
	# Add new entry if not found
	current_player.quest_log.append({
		"quest_id": quest_id,
		"finished": true
	})
	print("Quest ", quest_id, " added to quest log as finished")
	quest_completed.emit(quest_id)

func get_quest_data(quest_id: int) -> QuestData:
	"""Get quest data from quests.tres database"""
	if quests_db:
		return quests_db.get_quest_by_id(quest_id)
	return null

# Function to set player traveling destination to quest
func accept_quest(quest_id: int):
	if current_player:
		current_player.traveling_destination = quest_id
		print("Player accepted quest ", quest_id, " and is now traveling to it")

# Function to set current combat for display
func set_current_combat_log(combat_index: int = 0):
	if combat_index >= 0 and combat_index < combat_logs.size():
		current_combat_log = combat_logs[combat_index]
		print("Set current combat log: You vs ", current_combat_log.player2_name)
	else:
		print("Invalid combat log index: ", combat_index)

# Function to get combat logs for a specific player (as opponent)
func get_combat_logs_for_player(player_name: String) -> Array[CombatResponse]:
	var player_combats: Array[CombatResponse] = []
	for combat in combat_logs:
		if combat.player2_name == player_name:
			player_combats.append(combat)
	return player_combats

# Helper function to get active perks for any GamePlayer (player or opponent)
func get_active_perks_for_character(character: GamePlayer) -> Array:
	var active_perks = []
	if character and character.perks:
		for perk in character.perks:
			if perk.active:
				active_perks.append(perk)
	return active_perks

# Helper function to get inactive perks for any GamePlayer
func get_inactive_perks_for_character(character: GamePlayer) -> Array:
	var inactive_perks = []
	if character and character.perks:
		for perk in character.perks:
			if not perk.active:
				inactive_perks.append(perk)
	return inactive_perks

# Debug function to print arena opponents info
func print_arena_opponents_info():
	print("\n=== Enemy Players Info (First 5) ===")
	for i in range(min(5, enemy_players.size())):
		var opponent = enemy_players[i]
		print("Player ", i + 1, ":")
		print("  Name: ", opponent.name, " (Rank: ", opponent.rank, ")")
		print("  Stats: STR=", opponent.strength, " STA=", opponent.stamina, " AGI=", opponent.agility, " LCK=", opponent.luck, " ARM=", opponent.armor)
		print("  Active Perks: ", opponent.get_active_perks().size())
		print("  Inactive Perks: ", opponent.get_inactive_perks().size())
		print("  Items: ", opponent.bag_slots.size())
		print("  Talents: ", opponent.talents.size())
	print("=== End Enemy Players Info ===")
