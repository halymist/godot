class_name Settlement
extends Resource

# Matches server JSON from download_world()

@export var settlement_id: int = 0
@export var settlement_name: String = ""
@export var faction: int = 0
@export_multiline var description: String = ""
@export var settlement_asset_id: int = 0  # Map icon/thumbnail


# Expedition (flat fields)
@export var expedition_asset_id: int = 0
@export_multiline var expedition_description: String = ""
@export var expedition_failure: Array[String] = []  # Failure text lines for expeditions

# Arena
@export var arena_asset_id: int = 0

# Vendor
@export var vendor_asset_id: int = 0
@export var vendor_msg_bottom_left: Vector2 = Vector2.ZERO
@export var vendor_msg_bottom_right: Vector2 = Vector2.ZERO
# Settlement.gd
@export var vendor_on_entered: Array[String] = []
@export var vendor_on_sold: Array[String] = []
@export var vendor_on_bought: Array[String] = []

# Healer
@export var healer_asset_id: int = 0
@export var healer_msg_bottom_left: Vector2 = Vector2.ZERO
@export var healer_msg_bottom_right: Vector2 = Vector2.ZERO
@export var healer_on_entered: Array[String] = []
@export var healer_on_healed: Array[String] = []
@export var healer_on_cured: Array[String] = []


# Utility (one per settlement: blacksmith/alchemist/enchanter/trainer/church)
@export var utility_type: String = ""  # "blacksmith", "alchemist", "enchanter", "trainer", "church"
@export var utility_asset_id: int = 0
@export var utility_msg_bottom_left: Vector2 = Vector2.ZERO
@export var utility_msg_bottom_right: Vector2 = Vector2.ZERO
@export var utility_on_entered: Array[String] = []
@export var utility_on_placed: Array[String] = []
@export var utility_on_action: Array[String] = []
var utilities: Array[Dictionary] = []
var active_utility_slot: int = 1

# Church-only blessings (perk IDs)
@export var blessing1: int = 0
@export var blessing2: int = 0
@export var blessing3: int = 0

# Runtime textures (not saved to .res)
var expedition_texture: Texture2D = null
var vendor_texture: Texture2D = null
var healer_texture: Texture2D = null
var utility_texture: Texture2D = null
var utility_texture_asset_id: int = 0
var arena_background: Texture2D = null
var settlement_texture: Texture2D = null  # Map icon/thumbnail

func get_expedition_texture() -> Texture2D:
	if not expedition_texture and expedition_asset_id > 0:
		expedition_texture = DataManager.load_asset_texture("settlements", expedition_asset_id)
	return expedition_texture

func get_vendor_texture() -> Texture2D:
	if not vendor_texture and vendor_asset_id > 0:
		vendor_texture = DataManager.load_asset_texture("settlements", vendor_asset_id)
	return vendor_texture

func get_healer_texture() -> Texture2D:
	if not healer_texture and healer_asset_id > 0:
		healer_texture = DataManager.load_asset_texture("settlements", healer_asset_id)
	return healer_texture

func get_utility_texture() -> Texture2D:
	if utility_texture_asset_id != utility_asset_id:
		utility_texture = null
		utility_texture_asset_id = utility_asset_id
	if not utility_texture and utility_asset_id > 0:
		utility_texture = DataManager.load_asset_texture("settlements", utility_asset_id)
	return utility_texture

func get_arena_background() -> Texture2D:
	if not arena_background and arena_asset_id > 0:
		arena_background = DataManager.load_asset_texture("settlements", arena_asset_id)
	return arena_background

func get_settlement_texture() -> Texture2D:
	if not settlement_texture and settlement_asset_id > 0:
		settlement_texture = DataManager.load_asset_texture("settlements", settlement_asset_id)
	return settlement_texture

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

func has_healer() -> bool:
	return healer_asset_id > 0

func has_vendor_msg_rect() -> bool:
	return vendor_msg_bottom_left != vendor_msg_bottom_right

func has_healer_msg_rect() -> bool:
	return healer_msg_bottom_left != healer_msg_bottom_right

func has_utility() -> bool:
	return utility_type != "" and utility_asset_id > 0

func has_utility_msg_rect() -> bool:
	return utility_msg_bottom_left != utility_msg_bottom_right

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

func get_utility_slot(slot: int) -> Dictionary:
	for utility_data in utilities:
		if int(utility_data.get("slot", 0)) == slot:
			return utility_data
	return {}

func select_utility_slot(slot: int) -> bool:
	var utility_data = get_utility_slot(slot)
	if utility_data.is_empty():
		return false
	active_utility_slot = slot
	utility_type = str(utility_data.get("type", ""))
	utility_asset_id = int(utility_data.get("utility_asset_id", 0))
	utility_msg_bottom_left = utility_data.get("msg_bottom_left", Vector2.ZERO)
	utility_msg_bottom_right = utility_data.get("msg_bottom_right", Vector2.ZERO)
	utility_on_entered = _entry_lines(utility_data, "on_entered")
	utility_on_placed = _entry_lines(utility_data, "on_placed")
	utility_on_action = _entry_lines(utility_data, "on_action")
	blessing1 = int(utility_data.get("blessing1", 0))
	blessing2 = int(utility_data.get("blessing2", 0))
	blessing3 = int(utility_data.get("blessing3", 0))
	return has_utility()

func _entry_lines(utility_data: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var raw_lines = utility_data.get(key, [])
	if raw_lines is Array:
		for line in raw_lines:
			result.append(str(line))
	return result

# Get vendor greeting arrays (split by newlines)
func get_vendor_on_entered_lines() -> Array[String]:
	return _split_lines(vendor_on_entered)

func get_vendor_on_sold_lines() -> Array[String]:
	return _split_lines(vendor_on_sold)

func get_vendor_on_bought_lines() -> Array[String]:
	return _split_lines(vendor_on_bought)

func get_healer_on_entered_lines() -> Array[String]:
	return _split_lines(healer_on_entered)

func get_healer_on_healed_lines() -> Array[String]:
	return _split_lines(healer_on_healed)

func get_healer_on_cured_lines() -> Array[String]:
	return _split_lines(healer_on_cured)

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
