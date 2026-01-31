class_name Settlement
extends Resource

# Matches server JSON from download_world()

@export var settlement_id: int = 0
@export var settlement_name: String = ""
@export var faction: int = 0
@export_multiline var description: String = ""


# Expedition (flat fields)
@export var expedition_asset_id: int = 0
@export_multiline var expedition_description: String = ""

# Arena
@export var arena_asset_id: int = 0

# Vendor
@export var vendor_asset_id: int = 0
# Settlement.gd
@export var vendor_on_entered: Array[String] = []
@export var vendor_on_sold: Array[String] = []
@export var vendor_on_bought: Array[String] = []


# Utility (one per settlement: blacksmith/alchemist/enchanter/trainer/church)
@export var utility_type: String = ""  # "blacksmith", "alchemist", "enchanter", "trainer", "church"
@export var utility_asset_id: int = 0
@export var utility_on_entered: Array[String] = []
@export var utility_on_placed: Array[String] = []
@export var utility_on_action: Array[String] = []

# Church-only blessings (perk IDs)
@export var blessing1: int = 0
@export var blessing2: int = 0
@export var blessing3: int = 0

# Runtime textures (not saved to .res)
var expedition_texture: Texture2D = null
var vendor_texture: Texture2D = null
var utility_texture: Texture2D = null
var arena_background: Texture2D = null

# Backwards compatibility aliases
var location_id: int:
	get: return settlement_id
var location_name: String:
	get: return settlement_name
var expedition_text: String:
	get: return expedition_description

# Helper functions
func has_vendor() -> bool:
	return vendor_asset_id > 0

func has_utility() -> bool:
	return utility_type != "" and utility_asset_id > 0

func has_blacksmith() -> bool:
	return utility_type == "blacksmith"

# Get blessings array (for church)
func get_blessings() -> Array[int]:
	var result: Array[int] = []
	if blessing1 > 0:
		result.append(blessing1)
	if blessing2 > 0:
		result.append(blessing2)
	if blessing3 > 0:
		result.append(blessing3)
	return result

func has_alchemist() -> bool:
	return utility_type == "alchemist"

func has_enchanter() -> bool:
	return utility_type == "enchanter"

func has_trainer() -> bool:
	return utility_type == "trainer"

func has_church() -> bool:
	return utility_type == "church"

# Get vendor greeting arrays (split by newlines)
func get_vendor_on_entered_lines() -> Array[String]:
	return _split_lines(vendor_on_entered)

func get_vendor_on_sold_lines() -> Array[String]:
	return _split_lines(vendor_on_sold)

func get_vendor_on_bought_lines() -> Array[String]:
	return _split_lines(vendor_on_bought)

# Get utility greeting arrays (split by newlines)
func get_utility_on_entered_lines() -> Array[String]:
	return _split_lines(utility_on_entered)

func get_utility_on_placed_lines() -> Array[String]:
	return _split_lines(utility_on_placed)

func get_utility_on_action_lines() -> Array[String]:
	return _split_lines(utility_on_action)

func _split_lines(lines: Array[String]) -> Array[String]:
	"""Trim each line, filter empty lines"""
	var result: Array[String] = []
	for line in lines:
		var trimmed = line.strip_edges()
		if not trimmed.is_empty():
			result.append(trimmed)
	return result
