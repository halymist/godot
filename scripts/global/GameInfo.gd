extends Node
@export var fallback_folder: String = "res://assets/images/fallback"
# Persistent game data manager - AutoLoad
# This holds all player data permanently, separate from UI

# Static game data
var effects_db: EffectDatabase = null
var items_db: ItemDatabase = null
var perks_db: PerkDatabase = null
var npcs_db: NpcDatabase = null

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

# Guild names and icons mapping
const GUILD_DATA = {
	1: {"name": "Mercantile", "icon": "res://assets/icons/guild_mercantile.png"},
	2: {"name": "Warriors", "icon": "res://assets/icons/guild_warriors.png"},
	3: {"name": "Mages", "icon": "res://assets/icons/guild_mages.png"}
}

func get_guild_name(guild_id: int) -> String:
	"""Get the guild name for a given guild ID"""
	var data = GUILD_DATA.get(guild_id, {})
	return data.get("name", "None")

func get_guild_icon(guild_id: int) -> String:
	"""Get the guild icon path for a given guild ID"""
	var data = GUILD_DATA.get(guild_id, {})
	return data.get("icon", "")

# Profession names and icons mapping
const PROFESSION_DATA = {
	1: {"name": "Herbalist", "icon": "res://assets/icons/profession_herbalist.png"},
	2: {"name": "Blacksmith", "icon": "res://assets/icons/profession_blacksmith.png"},
	3: {"name": "Enchanter", "icon": "res://assets/icons/profession_enchanter.png"},
	4: {"name": "Warrior", "icon": "res://assets/icons/profession_warrior.png"}
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
signal gold_changed(new_gold)
signal currency_changed(new_currency)
signal stats_changed(stats)
signal bag_slots_changed
signal on_player_data_loaded
signal current_panel_changed(new_panel)
signal current_panel_overlay_changed(new_overlay) # panels that partially cover the screen
signal npc_clicked(npc) # Global NPC click signal
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
				else:
					# Log missing key for debugging
					print("Warning: Missing key '", msgpack_key, "' in MessagePack data for class ", get_script().get_global_name())
	
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
	
	# MessagePack properties matching C# Item class
	var id: int = 0
	var bag_slot_id: int = 0
	var item_name: String = ""
	var type: String = ""
	var armor: int = 0
	var strength: int = 0
	var stamina: int = 0
	var agility: int = 0
	var luck: int = 0
	var damage_min: int = 0
	var damage_max: int = 0
	var asset_id: int = 0
	var effect_id: int = 0
	var effect_name: String = ""  # Looked up from effects_db
	var effect_description: String = ""  # Looked up from effects_db
	var effect_factor: float = 0.0
	var quality: int = 0
	var price: int = 0
	var tempered: int = 0  # Tracks tempering level (0 = not tempered, 1+ = tempered)
	var enchant_overdrive: int = 0  # Enchanting overdrive level
	var day: int = 0  # Day when item was acquired (for stat scaling: 2% per day)
	
	# Client-side only (not serialized)
	var texture: Texture2D = null
	
	# MessagePack field mapping matching your actual data format
	const MSGPACK_MAP = {
		"id": "id",
		"bag_slot_id": "bag_slot_id",
		"item_name": "item_name",
		"type": "type",
		"subtype": "subtype",
		"armor": "armor",
		"strength": "strength",
		"stamina": "stamina",
		"agility": "agility",
		"luck": "luck",
		"damage_min": "damage_min",
		"damage_max": "damage_max",
		"asset_id": "asset_id",
		"effect_id": "effect_id",
		"effect_factor": "effect_factor",
		"quality": "quality",
		"price": "price",
		"tempered": "tempered",
		"enchant_overdrive": "enchant_overdrive",
		"effect_overdrive": "enchant_overdrive",
		"day": "day"
	}
	
	func _init(data: Dictionary = {}):
		super._init(data)
		# Get item data from items_db if available
		if GameInfo and GameInfo.items_db:
			var item_resource = GameInfo.items_db.get_item_by_id(id)
			if item_resource:
				# Copy static data from resource
				item_name = item_resource.item_name
				type = item_resource.type
				armor = item_resource.armor
				strength = item_resource.strength
				stamina = item_resource.stamina
				agility = item_resource.agility
				luck = item_resource.luck
				damage_min = item_resource.damage_min
				damage_max = item_resource.damage_max
				effect_id = item_resource.effect_id
				effect_factor = item_resource.effect_factor
				quality = item_resource.quality
				price = item_resource.price
				tempered = item_resource.tempered
				# Note: enchant_overdrive comes from server data, not items_db
				texture = item_resource.icon
		
		# Apply tempering improvements if item is tempered
		# Each tempering level adds 10% to base stats (compounding)
		if tempered > 0:
			var multiplier = pow(1.1, tempered)
			armor = ceil(armor * multiplier)
			strength = ceil(strength * multiplier)
			stamina = ceil(stamina * multiplier)
			agility = ceil(agility * multiplier)
			luck = ceil(luck * multiplier)
		
		# Apply day-based scaling (2% improvement per day, compounding)
		# day represents when the item was acquired, so we scale by (1.02^day)
		if day > 0:
			var day_multiplier = pow(1.02, day)
			armor = ceil(armor * day_multiplier)
			strength = ceil(strength * day_multiplier)
			stamina = ceil(stamina * day_multiplier)
			agility = ceil(agility * day_multiplier)
			luck = ceil(luck * day_multiplier)
			damage_min = ceil(damage_min * day_multiplier)
			damage_max = ceil(damage_max * day_multiplier)
		
		# Handle effect_overdrive: override effect with data from effects_db
		# enchant_overdrive comes from server data (via MSGPACK), not items_db
		if enchant_overdrive > 0 and GameInfo and GameInfo.effects_db:
			var overdrive_effect = GameInfo.effects_db.get_effect_by_id(enchant_overdrive)
			if overdrive_effect:
				effect_id = enchant_overdrive
				effect_factor = overdrive_effect.factor
				effect_name = overdrive_effect.name
				effect_description = overdrive_effect.description
		else:
			# No effect_overdrive: look up effect details from effects_db
			if GameInfo and GameInfo.effects_db and effect_id > 0:
				var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
				if effect:
					effect_name = effect.name
					effect_description = effect.description

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
class RankingEntry:
	extends RefCounted
	
	var name: String = ""
	var rank: int = 0
	var guild: int = 0
	var profession: int = 0
	var honor: int = 0
	
	func _init(data: Dictionary = {}):
		name = data.get("name", "")
		rank = data.get("rank", 0)
		guild = data.get("guild", 0)
		profession = data.get("profession", 0)
		honor = data.get("honor", 0)

class QuestOption:
	extends MessagePackObject
	
	# MessagePack properties matching Go QuestOption struct
	var option_index: int = 0
	var type: String = ""
	var text: String = ""
	var slide_target: int = 0
	var enemy: int = 0
	var on_win_slide: int = 0
	var on_loose_slide: int = 0
	
	const MSGPACK_MAP = {
		"optionIndex": "option_index",
		"type": "type",
		"text": "text",
		"slideTarget": "slide_target",
		"enemy": "enemy",
		"onWinSlide": "on_win_slide",
		"onLooseSlide": "on_loose_slide"
	}

class QuestSlide:
	extends MessagePackObject
	
	# MessagePack properties matching Go QuestSlide struct
	var slide: int = 0
	var asset_id: int = 0
	var text: String = ""
	var options: Array[QuestOption] = []
	var reward: Dictionary = {}
	
	const MSGPACK_MAP = {
		"slide": "slide",
		"assetID": "asset_id",
		"text": "text",
		"options": "options",
		"reward": "reward"
	}
	
	func load_from_msgpack(data: Dictionary):
		super.load_from_msgpack(data)
		# Convert options array
		if data.has("options") and data["options"] is Array:
			options.clear()
			for option_data in data["options"]:
				if option_data is Dictionary:
					var option = QuestOption.new(option_data)
					options.append(option)

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
	
	var turn: int = 0
	var player: String = ""
	var action: String = ""
	var factor: int = 0  # Optional damage/heal amount
	
	const MSGPACK_MAP = {
		"turn": "turn",
		"player": "player",
		"action": "action",
		"factor": "factor"
	}

class CombatResponse:
	extends MessagePackObject
	
	var player1_name: String = ""
	var player1_health: int = 0
	var player2_name: String = ""
	var player2_health: int = 0
	var final_message: String = ""
	var combat_log: Array[CombatLogEntry] = []
	
	const MSGPACK_MAP = {
		"player1name": "player1_name",
		"player1health": "player1_health",
		"player2name": "player2_name", 
		"player2health": "player2_health",
		"final_message": "final_message",
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
	
	# Base properties shared by CurrentPlayer and ArenaOpponent
	var name: String = ""
	var strength: int = 0
	var stamina: int = 0
	var agility: int = 0
	var luck: int = 0
	var armor: int = 0
	var bag_slots: Array[Item] = []
	var perks: Array[Perk] = []
	var talents: Array[Talent] = []
	
	# Base MessagePack fields shared by all players
	const MSGPACK_MAP = {
		"name": "name",
		"strength": "strength",
		"stamina": "stamina",
		"agility": "agility",
		"luck": "luck",
		"armor": "armor"
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
		
		return total_stats
	
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

class GameCurrentPlayer:
	extends GamePlayer
	
	# Current player specific properties with automatic events
	var location: int = 1
	var traveling: int = 0  # Unix timestamp when travel ends, 0 if not traveling
	var traveling_destination: Variant = null
	var dungeon: bool = false
	var destination: Variant = null
	var slide: Variant = null
	var slides: Array = []
	var talent_points: int = 0
	var perk_points: int = 0
	var blessing: int = 0  # Active blessing effect ID (0 = no blessing)
	var potion: int = 0  # Equipped potion item ID (0 = no potion)
	var elixir: int = 0  # Equipped elixir item ID (0 = no elixir)
	var quest_log: Array = []  # Array of {quest_id: int, status: String} to track quest completion
	var guild: int = 0  # Guild ID (1=Mercantile, 2=Warriors, 3=Mages, etc.)
	var rank: int = 0  # Rank value (determines rank tier like Novice, Veteran, etc.)
	var profession: int = 0  # Profession ID (1=Herbalist, 2=Blacksmith, etc.)
	var daily_quests: Array = []  # Array of quest IDs available today
	
	# Gold with automatic event emission
	var _gold: int = 0
	var gold: int:
		get: return _gold
		set(value):
			_gold = value
			if game_info_ref:
				game_info_ref.gold_changed.emit(_gold)
	
	# Currency with automatic event emission
	var _currency: int = 0
	var currency: int:
		get: return _currency
		set(value):
			_currency = value
			if game_info_ref:
				game_info_ref.currency_changed.emit(_currency)
	
	# Extended MessagePack mapping (includes base + current player fields)
	const CURRENT_PLAYER_MSGPACK_MAP = {
		# Base fields
		"name": "name",
		"strength": "strength",
		"stamina": "stamina",
		"agility": "agility",
		"luck": "luck",
		"armor": "armor",
		# Current player specific fields
		"location": "location",
		"traveling": "traveling",
		"traveling_destination": "traveling_destination",
		"gold": "_gold",  # Use private field to avoid triggering setter
		"currency": "_currency",  # Use private field to avoid triggering setter
		"talent_points": "talent_points",
		"perk_points": "perk_points",
		"blessing": "blessing",
		"potion": "potion",
		"elixir": "elixir",
		"dungeon": "dungeon",
		"destination": "destination",
		"slide": "slide",
		"slides": "slides",
		"quest_log": "quest_log",
		"guild": "guild",
		"rank": "rank",
		"profession": "profession",
		"daily_quests": "daily_quests"
	}
	
	func load_from_msgpack(data: Dictionary):
		# Load using extended mapping
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
		
		# Trigger property setters for gold/currency to emit signals
		gold = _gold
		currency = _currency
		
		# Emit bag slots changed and stats changed
		if game_info_ref:
			game_info_ref.bag_slots_changed.emit()
			game_info_ref.stats_changed.emit(get_player_stats())
	
	func get_player_stats() -> Dictionary:
		var stats = get_total_stats()
		stats["gold"] = gold
		stats["currency"] = currency
		stats["talent_points"] = talent_points
		stats["perk_points"] = perk_points
		return stats
	
	# Helper functions to convert IDs to display names
	func get_guild_name() -> String:
		return GameInfo.get_guild_name(guild)
	
	func get_rank_name() -> String:
		# For now always return Novice, later we can add logic based on rank value
		return "Novice"
	
	func get_profession_name() -> String:
		return GameInfo.get_profession_name(profession)

class GameArenaOpponent:
	extends GamePlayer
	
	var rank: int = 0  # Rank value for arena opponents
	
	const ARENA_OPPONENT_MSGPACK_MAP = {
		# Base fields
		"name": "name",
		"strength": "strength",
		"stamina": "stamina",
		"agility": "agility",
		"luck": "luck",
		"armor": "armor",
		# Arena opponent specific
		"rank": "rank"
	}
	
	func _init(data: Dictionary = {}, game_info: GameInfo = null):
		super._init(data, game_info)
	
	func load_from_msgpack(data: Dictionary):
		# Load using arena opponent mapping
		var msgpack_map = ARENA_OPPONENT_MSGPACK_MAP
		for msgpack_key in msgpack_map:
			if data.has(msgpack_key):
				var local_key = msgpack_map[msgpack_key]
				set(local_key, data[msgpack_key])
		
		# Load arrays
		load_bag_slots(data)
		load_perks(data)
		load_talents(data)
	
	func get_rank_name() -> String:
		# Same logic as current player for now
		return "Novice"

# GameInfo main class properties
var current_player: GameCurrentPlayer
var arena_opponents: Array[GameArenaOpponent] = []
var arena_opponent: GameArenaOpponent = null
var chat_messages: Array[ChatMessage] = []
var combat_logs: Array[CombatResponse] = []
var current_combat_log: CombatResponse = null
var npcs: Array[Dictionary] = []
var vendor_items: Array[Item] = []
var rankings: Array[RankingEntry] = []  # Rankings list (lightweight data)

# Quest system
var quest_slides: Dictionary = {}  # questID -> Array[QuestSlide]

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
var player_gold: int:
	get: return current_player.gold if current_player else 0
	set(value): 
		if current_player:
			current_player.gold = value

var player_currency: int:
	get: return current_player.currency if current_player else 0
	set(value):
		if current_player:
			current_player.currency = value

func _ready():
	print("GameInfo ready!")
	# Load effects database first (items and perks reference these)
	if ResourceLoader.exists("res://data/effects.tres"):
		effects_db = load("res://data/effects.tres")
		print("Effects database loaded: ", effects_db.effects.size(), " effects")
	else:
		print("Warning: effects.tres not found")
	
	# Load static databases
	if ResourceLoader.exists("res://data/items.tres"):
		items_db = load("res://data/items.tres")
		print("Items database loaded: ", items_db.items.size(), " items")
	else:
		print("Warning: items.tres not found, items will use fallback textures")
	
	if ResourceLoader.exists("res://data/perks.tres"):
		perks_db = load("res://data/perks.tres")
		print("Perks database loaded: ", perks_db.perks.size(), " perks")
	else:
		print("Warning: perks.tres not found, perks will have no data")
	
	if ResourceLoader.exists("res://data/npcs.tres"):
		npcs_db = load("res://data/npcs.tres")
		print("NPCs database loaded: ", npcs_db.npcs.size(), " NPCs")
	else:
		print("Warning: npcs.tres not found, NPCs will not spawn")
	
	load_player_data(Websocket.mock_character_data)
	load_arena_opponents_data(Websocket.mock_arena_opponents)
	load_chat_messages_data(Websocket.mock_chat_messages)
	load_rankings_data(Websocket.mock_rankings)
	load_combat_logs_data(Websocket.mock_combat_logs)
	load_vendor_items_data(Websocket.mock_vendor_items)
	# NPCs are now client-side resources - loaded from npcs.tres based on daily_quests
	load_all_quests_data(Websocket.mock_quests)  # Load all quests by ID
	set_current_combat_log(2)  # Set to wizard vs fire demon combat to show multi-action synchronization
	print_arena_opponents_info()

# Helper functions to modify values and emit signals
func add_gold(amount: int):
	if current_player:
		current_player.gold += amount

func add_currency(amount: int):
	if current_player:
		current_player.currency += amount

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
	print("Gold: ", current_player.gold)
	print("Items: ", current_player.bag_slots.size())
	print("Perks: ", current_player.perks.size())
	print("Talents: ", current_player.talents.size())

	on_player_data_loaded.emit()

func get_total_stats() -> Dictionary:
	return current_player.get_total_stats() if current_player else {}

# Function to load arena opponent from MessagePack format
func load_arena_opponent_msgpack(msgpack_data: Dictionary):
	arena_opponent = GameArenaOpponent.new(msgpack_data, self)
	print("Arena opponent loaded from MessagePack: ", arena_opponent.name)

# Function to load all arena opponents from mock data
func load_arena_opponents_data(opponents_data: Array):
	arena_opponents.clear()
	for opponent_data in opponents_data:
		var opponent = GameArenaOpponent.new(opponent_data, self)
		arena_opponents.append(opponent)
		print("Loaded arena opponent: ", opponent.name)
	print("Total arena opponents loaded: ", arena_opponents.size())

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
		var item = Item.new({"id": item_id})
		print("  Loaded vendor item: ", item.item_name)
		vendor_items.append(item)

func load_rankings_data(rankings_data: Array):
	rankings.clear()
	for entry_data in rankings_data:
		var entry = RankingEntry.new(entry_data)
		rankings.append(entry)
	print("Loaded ", rankings.size(), " ranking entries")
	rankings_loaded.emit()

# Function to load quest slides by quest ID
func load_quest_slides_data(quest_id: int, slides_data: Array):
	var slides_array: Array[QuestSlide] = []
	for slide_data in slides_data:
		var quest_slide = QuestSlide.new(slide_data)
		slides_array.append(quest_slide)
	quest_slides[quest_id] = slides_array
	print("Loaded quest ", quest_id, " with ", slides_array.size(), " slides")

# Function to load all quests from mock data
func load_all_quests_data(quests_data: Dictionary):
	quest_slides.clear()
	for quest_id in quests_data:
		var quest_info = quests_data[quest_id]
		if quest_info.has("slides"):
			load_quest_slides_data(quest_id, quest_info["slides"])
	print("Total quests loaded: ", quest_slides.size())

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

# Function to check if a specific quest slide has been visited
func has_visited_quest_slide(quest_id: int, slide_number: int) -> bool:
	if not current_player:
		return false
	for entry in current_player.quest_log:
		if entry.get("quest_id") == quest_id:
			var slides = entry.get("slides", [])
			return slide_number in slides
	return false

# Function to add a slide to quest log (tracks progress through quest)
func log_quest_slide(quest_id: int, slide_number: int):
	if not current_player:
		return
	
	# Find existing quest log entry
	for entry in current_player.quest_log:
		if entry.get("quest_id") == quest_id:
			# Add slide to slides array if not already there
			if not entry.has("slides"):
				entry["slides"] = []
			if slide_number not in entry["slides"]:
				entry["slides"].append(slide_number)
				print("Quest ", quest_id, " - logged slide ", slide_number)
			return
	
	# Create new entry if quest not in log yet
	var new_entry = {
		"quest_id": quest_id,
		"slides": [slide_number],
		"finished": false
	}
	current_player.quest_log.append(new_entry)
	print("Quest ", quest_id, " - created log with slide ", slide_number)

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
	
	# Add new entry if not found (quest abandoned before any slides were logged)
	current_player.quest_log.append({
		"quest_id": quest_id,
		"slides": [],
		"finished": true
	})
	print("Quest ", quest_id, " added to quest log as finished")
	quest_completed.emit(quest_id)

# Function to get quest slide by quest ID and slide number
func get_quest_slide(quest_id: int, slide_number: int) -> QuestSlide:
	if quest_slides.has(quest_id):
		var slides = quest_slides[quest_id]
		for slide in slides:
			if slide.slide == slide_number:
				return slide
	print("Quest slide not found: quest_id=", quest_id, " slide=", slide_number)
	return null

func get_quest_data(quest_id: int) -> Dictionary:
	"""Get quest metadata (name, id, etc)"""
	var quest_data = Websocket.mock_quests.get(quest_id, {})
	return quest_data

# Function to set player traveling destination to quest
func accept_quest(quest_id: int):
	if current_player:
		current_player.traveling_destination = quest_id
		print("Player accepted quest ", quest_id, " and is now traveling to it")

# Function to set current combat for display
func set_current_combat_log(combat_index: int = 0):
	if combat_index >= 0 and combat_index < combat_logs.size():
		current_combat_log = combat_logs[combat_index]
		print("Set current combat log: ", current_combat_log.player1_name, " vs ", current_combat_log.player2_name)
	else:
		print("Invalid combat log index: ", combat_index)

# Function to get combat logs for a specific player
func get_combat_logs_for_player(player_name: String) -> Array[CombatResponse]:
	var player_combats: Array[CombatResponse] = []
	for combat in combat_logs:
		if combat.player1_name == player_name or combat.player2_name == player_name:
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
	print("=== Arena Opponents Info ===")
	for i in range(arena_opponents.size()):
		var opponent = arena_opponents[i]
		print("Opponent ", i + 1, ":")
		print("  Name: ", opponent.name)
		print("  Stats: STR=", opponent.strength, " STA=", opponent.stamina, " AGI=", opponent.agility, " LCK=", opponent.luck, " ARM=", opponent.armor)
		print("  Active Perks: ", opponent.get_active_perks().size())
		print("  Inactive Perks: ", opponent.get_inactive_perks().size())
		print("  Items: ", opponent.bag_slots.size())
		print("  Talents: ", opponent.talents.size())
	print("=== End Arena Opponents Info ===")
