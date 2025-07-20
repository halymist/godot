extends Node
@export var fallback_folder: String = "res://assets/images/fallback"
# Persistent game data manager - AutoLoad
# This holds all player data permanently, separate from UI

# Signals for UI updates
signal gold_changed(new_gold)
signal currency_changed(new_currency)
signal stats_changed(stats)
signal bag_slots_changed
signal on_player_data_loaded
signal current_panel_changed(new_panel)
signal current_panel_overlay_changed(new_overlay) # panels that partially cover the screen

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
	var subtype: String = ""
	var armor: int = 0
	var strength: int = 0
	var constitution: int = 0
	var dexterity: int = 0
	var luck: int = 0
	var damage_min: int = 0
	var damage_max: int = 0
	var asset_id: int = 0
	var effect_name: String = ""
	var effect_description: String = ""
	var effect_factor: float = 0.0
	var quality: int = 0
	var price: int = 0
	
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
		"constitution": "constitution",
		"dexterity": "dexterity",
		"luck": "luck",
		"damage_min": "damage_min",
		"damage_max": "damage_max",
		"asset_id": "asset_id",
		"effect_name": "effect_name",
		"effect_description": "effect_description",
		"effect_factor": "effect_factor",
		"quality": "quality",
		"price": "price"
	}
	
	func _init(data: Dictionary = {}):
		super._init(data)
		# Assign texture after loading if asset_id exists
		if asset_id > 0 and GameInfo:
			texture = GameInfo.get_fallback_texture(asset_id)

class Perk:
	extends MessagePackObject
	
	# MessagePack properties matching C# Perk class
	var perk_name: String = ""
	var active: bool = false
	var description: String = ""
	var asset_id: int = 0
	var slot: int = 0
	var effect1: String = ""
	var factor1: float = 0.0
	var effect2: String = ""
	var factor2: float = 0.0
	
	# Client-side only
	var texture: Texture2D = null
	
	# MessagePack field mapping matching your actual data format
	const MSGPACK_MAP = {
		"perk_name": "perk_name",
		"active": "active",
		"description": "description",
		"asset_id": "asset_id",
		"slot": "slot",
		"effect1": "effect1",
		"factor1": "factor1",
		"effect2": "effect2",
		"factor2": "factor2"
	}
	
	func _init(data: Dictionary = {}):
		super._init(data)
		# Assign texture after loading if asset_id exists
		if asset_id > 0 and GameInfo:
			texture = GameInfo.get_fallback_texture(asset_id)

class Talent:
	extends MessagePackObject
	
	# MessagePack properties matching C# Talent class
	var talent_id: int = 0
	var points: int = 0
	
	const MSGPACK_MAP = {
		"talent_id": "talent_id",
		"points": "points"
	}

class GamePlayer:
	extends MessagePackObject
	
	# Events/Signals reference (for emitting from CurrentPlayer)
	var game_info_ref: GameInfo
	
	# Base properties shared by CurrentPlayer and ArenaOpponent
	var name: String = ""
	var strength: int = 0
	var constitution: int = 0
	var dexterity: int = 0
	var luck: int = 0
	var armor: int = 0
	var bag_slots: Array[Item] = []
	var perks: Array[Perk] = []
	var talents: Array[Talent] = []
	
	# Base MessagePack fields shared by all players
	const MSGPACK_MAP = {
		"name": "name",
		"strength": "strength",
		"constitution": "constitution",
		"dexterity": "dexterity",
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
			"stamina": constitution,  # Map constitution to stamina for UI
			"agility": dexterity,     # Map dexterity to agility for UI
			"luck": luck,
			"armor": armor
		}
	
	func get_total_stats() -> Dictionary:
		var total_stats = get_base_stats()
		
		# Add stats from equipped items (slots 0-9)
		for item in bag_slots:
			if item.bag_slot_id >= 0 and item.bag_slot_id < 10:
				total_stats.strength += item.strength
				total_stats.stamina += item.constitution
				total_stats.agility += item.dexterity
				total_stats.luck += item.luck
				total_stats.armor += item.armor
		
		return total_stats
	
	func has_talent(talent_id: int) -> bool:
		for talent in talents:
			if talent.talent_id == talent_id:
				return true
		return false

class GameCurrentPlayer:
	extends GamePlayer
	
	# Current player specific properties with automatic events
	var location: String = ""
	var traveling: Variant = null
	var dungeon: bool = false
	var destination: Variant = null
	var slide: Variant = null
	var slides: Array = []
	var talent_points: int = 0
	var perk_points: int = 0
	
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
		"constitution": "constitution",
		"dexterity": "dexterity",
		"luck": "luck",
		"armor": "armor",
		# Current player specific fields
		"location": "location",
		"traveling": "traveling",
		"gold": "_gold",  # Use private field to avoid triggering setter
		"currency": "_currency",  # Use private field to avoid triggering setter
		"talent_points": "talent_points",
		"perk_points": "perk_points",
		"dungeon": "dungeon",
		"destination": "destination",
		"slide": "slide",
		"slides": "slides"
	}
	
	func load_from_msgpack(data: Dictionary):
		# Load using extended mapping
		var msgpack_map = CURRENT_PLAYER_MSGPACK_MAP
		for msgpack_key in msgpack_map:
			if data.has(msgpack_key):
				var local_key = msgpack_map[msgpack_key]
				set(local_key, data[msgpack_key])
		
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

class GameArenaOpponent:
	extends GamePlayer	
	# ArenaOpponent has no additional fields beyond Player
	
	func _init(data: Dictionary = {}, game_info: GameInfo = null):
		super._init(data, game_info)

# GameInfo main class properties
var current_player: GameCurrentPlayer
var arena_opponent: GameArenaOpponent = null

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
	load_player_data(Websocket.mock_character_data)

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
