extends TextureRect

# EnchanterPanel-specific functionality

# Slot numbering constants
const ENCHANTER_SLOT = 15
const BAG_MIN = 10
const BAG_MAX = 14

@export var chat_bubble: ChatBubble
@export var bag: Control
@export var enchanter_slot: Control
@export var enchant_button: Button
@export var slot_type_button_1: Button
@export var slot_type_button_2: Button
@export var slot_type_button_3: Button
@export var slot_type_button_4: Button
@export var effect_list: Container
@export var effect_description: Label
@export var enchant_option_scene: PackedScene

const ENCHANT_COST = 10
const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")
const COLOR_PRICE_NORMAL = Color(0.85, 0.8, 0.7, 1.0)
const COLOR_PRICE_MISSING = Color(1.0, 0.25, 0.2, 1.0)
const EQUIPPABLE_TYPES: Array[String] = ["Head", "Chest", "Hands", "Foot", "Belt", "Legs", "Ring", "Amulet", "Weapon"]
const DEBUG_ENCHANTER := true
const SLOT_TYPE_ICONS := {
	"Head": preload("res://assets/images/ui/helmet_outline.png"),
	"Chest": preload("res://assets/images/ui/chest_outline.png"),
	"Hands": preload("res://assets/images/ui/gloves_outline.png"),
	"Foot": preload("res://assets/images/ui/shoes_outline.png"),
	"Belt": preload("res://assets/images/ui/belt_outline.png"),
	"Legs": preload("res://assets/images/ui/pants_outline.png"),
	"Ring": preload("res://assets/images/ui/ring_outline.png"),
	"Amulet": preload("res://assets/images/ui/amulet_outline.png"),
	"Weapon": preload("res://assets/images/ui/sword_outline.png")
}

var on_entered_greetings: Array[String] = []
var on_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []
var selected_effect_id: int = 0
var selected_effect_factor: float = 0.0
var selected_slot_type: String = ""
var effect_groups: Dictionary = {}
var slot_type_order: Array[String] = []
var working_item: GameInfo.Item = null  # Reference to item being worked on (doesn't change bag_slot_id)
var _did_refresh_effects_db: bool = false
var _slot_type_button_styles: Dictionary = {}

func _ready():
	visibility_changed.connect(_on_visibility_changed)
	enchant_button.pressed.connect(_on_enchant_pressed)
	if not GameInfo.enchanter_inventory_updated.is_connected(_on_enchanter_inventory_updated):
		GameInfo.enchanter_inventory_updated.connect(_on_enchanter_inventory_updated)
	for button in _get_slot_type_buttons():
		button.visible = true
		button.toggle_mode = true
		button.text = ""
		button.flat = false
		button.expand_icon = true
		_apply_slot_type_button_style(button, false)
		if not button.pressed.is_connected(_on_slot_type_button_pressed.bind(button)):
			button.pressed.connect(_on_slot_type_button_pressed.bind(button))
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _on_enchanter_inventory_updated():
	_log_debug("received enchanter_inventory_updated")
	populate_effect_list()

func _setup():
	var enchanter_payload: Variant = null
	if GameInfo.current_player:
		enchanter_payload = GameInfo.current_player.enchanter_effects
	_log_debug("_setup current_player.enchanter_effects=%s fallback_payload=%s" % [str(enchanter_payload), str(GameInfo.last_player_enchanter_payload)])
	_load_location_content()
	update_enchant_button_state()
	populate_effect_list()

func on_item_placed(item: GameInfo.Item, _source_slot_id: int):
	"""Called when an item is placed in the enchanter slot (item keeps its original bag_slot_id)"""
	if not can_accept_item(item):
		if enchanter_slot and enchanter_slot.has_method("clear_slot"):
			enchanter_slot.clear_slot()
		UIManager.instance.refresh_bags()
		return

	working_item = item
	var item_slot_type = _normalize_equipment_type(item.type)
	if effect_groups.has(item_slot_type):
		selected_slot_type = item_slot_type
	elif effect_groups.has("Any"):
		selected_slot_type = "Any"
	_show_greeting(on_placed_greetings)
	update_enchant_button_state()
	populate_effect_list()

func on_item_removed():
	"""Called when an item is removed from the enchanter slot"""
	working_item = null
	update_enchant_button_state()
	populate_effect_list()

func get_working_item() -> GameInfo.Item:
	"""Return the item currently being worked on (for excluding from bag refresh)"""
	return working_item

func on_slot_changed(_slot_id: int):
	"""Legacy - Called by UIManager when a utility slot changes (for compatibility)"""
	# This is now handled by on_item_placed/on_item_removed
	pass

func _on_visibility_changed():
	if not visible:
		return_enchanter_item_to_bag()
	else:
		update_enchant_button_state()
		populate_effect_list()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
	if not settlement:
		return
	
	# Apply utility texture directly to self
	var utility_texture = settlement.get_utility_texture()
	if utility_texture:
		texture = utility_texture
	
	# Load utility greetings from settlement
	on_entered_greetings = settlement.get_utility_on_entered_lines()
	on_placed_greetings = settlement.get_utility_on_placed_lines()
	on_action_greetings = settlement.get_utility_on_action_lines()

	if chat_bubble:
		if settlement.has_utility_msg_rect():
			chat_bubble.set_message_bounds(settlement.utility_msg_bottom_left, settlement.utility_msg_bottom_right)
		else:
			chat_bubble.clear_message_bounds()

func _show_greeting(greetings: Array[String]):
	if not chat_bubble or greetings.is_empty():
		return
	var greeting = greetings[randi() % greetings.size()]
	chat_bubble.show_with_text(greeting, 4.0)

func return_enchanter_item_to_bag():
	# Just clear the visual slot and reset working_item
	# The item never actually moved - it keeps its original bag_slot_id
	if working_item:
		working_item = null
		if enchanter_slot.has_method("clear_slot"):
			enchanter_slot.clear_slot()
		UIManager.instance.refresh_bags()

func update_enchant_button_state():
	var has_item = working_item != null
	var has_silver = GameInfo.current_player.silver >= ENCHANT_COST
	var has_selection = selected_effect_id > 0
	var item_allowed = working_item == null or can_accept_item(working_item)
	enchant_button.disabled = not (has_item and has_silver and has_selection and item_allowed)
	_set_price_label_color(enchant_button, has_silver)

func _set_price_label_color(button: Button, can_afford: bool):
	var price_label = button.get_node_or_null("Content/PriceLabel") as Label
	if price_label:
		price_label.add_theme_color_override("font_color", COLOR_PRICE_NORMAL if can_afford else COLOR_PRICE_MISSING)

func populate_effect_list():
	_build_effect_groups()
	_select_default_slot_type_if_needed()
	_log_debug("populate_effect_list groups=%s selected=%s" % [str(slot_type_order), selected_slot_type])
	populate_slot_type_toggles()
	populate_effect_options()
	update_enchant_button_state()

func populate_slot_type_toggles():
	var buttons = _get_slot_type_buttons()
	_log_debug("populate_slot_type_toggles button_count=%d slot_type_order=%s" % [buttons.size(), str(slot_type_order)])
	for index in range(buttons.size()):
		var button = buttons[index]
		button.visible = true
		if index < slot_type_order.size():
			var slot_type_name = slot_type_order[index]
			button.text = ""
			button.icon = SLOT_TYPE_ICONS.get(slot_type_name, null)
			button.disabled = false
			button.button_pressed = slot_type_name == selected_slot_type
			_apply_slot_type_button_style(button, button.button_pressed)
			button.set_meta("slot_type_name", slot_type_name)
			_log_debug("toggle[%d] visible slot=%s pressed=%s" % [index, slot_type_name, str(button.button_pressed)])
		else:
			button.text = ""
			button.icon = _get_default_toggle_icon(index)
			button.disabled = false
			button.button_pressed = false
			_apply_slot_type_button_style(button, false)
			button.remove_meta("slot_type_name")

func populate_effect_options():
	for child in effect_list.get_children():
		child.queue_free()
	
	selected_effect_id = 0
	selected_effect_factor = 0.0
	_set_effect_description(null)

	var effects = effect_groups.get(selected_slot_type, [])
	for index in range(effects.size()):
		var effect = effects[index]
		
		var option = enchant_option_scene.instantiate()
		option.setup(effect)
		option.text = _get_effect_title(effect)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.pressed.connect(_on_effect_selected.bind(effect.id, effect.factor, option))
		effect_list.add_child(option)
		if index == 0:
			_on_effect_selected(effect.id, effect.factor, option)

func can_accept_item(item: GameInfo.Item) -> bool:
	if not item:
		return false
	return can_accept_item_type(item.type)

func can_accept_item_type(item_type: String) -> bool:
	_build_effect_groups()
	var normalized_type = _normalize_equipment_type(item_type)
	if normalized_type not in EQUIPPABLE_TYPES:
		return false
	return effect_groups.has(normalized_type) or effect_groups.has("Any")

func _build_effect_groups():
	effect_groups.clear()
	slot_type_order.clear()
	if not GameInfo.effects_db:
		_log_debug("_build_effect_groups aborted current_player=%s effects_db=%s" % [str(GameInfo.current_player != null), str(GameInfo.effects_db != null)])
		return
	var payload = _get_enchanter_payload()
	_log_debug("_build_effect_groups payload=%s" % [str(payload)])
	_add_effects_from_payload(payload)
	if slot_type_order.is_empty() and not _did_refresh_effects_db and _payload_has_effect_entries(payload):
		_log_debug("No slot groups resolved from payload; forcing effects DB reload once")
		_reload_effects_db()
		effect_groups.clear()
		slot_type_order.clear()
		_add_effects_from_payload(payload)
	_log_debug("_build_effect_groups result order=%s groups=%s" % [str(slot_type_order), _describe_effect_groups()])

func _add_effects_from_payload(payload: Variant, forced_slot_type: String = ""):
	if payload is Array:
		for entry in payload:
			_add_effects_from_payload(entry, forced_slot_type)
	elif payload is Dictionary:
		var slot_type_name = str(payload.get("slot_type", payload.get("type", payload.get("slot", forced_slot_type))))
		if payload.has("effects"):
			_add_effects_from_payload(payload.effects, slot_type_name)
		elif payload.has("effect_id"):
			_add_effect_id(int(payload.effect_id), slot_type_name)
		elif payload.has("id"):
			_add_effect_id(int(payload.id), slot_type_name)
		else:
			for key in payload.keys():
				_add_effects_from_payload(payload[key], str(key))
	elif payload is int or payload is float:
		_add_effect_id(int(payload), forced_slot_type)
	elif payload is String and payload.is_valid_int():
		_add_effect_id(int(payload), forced_slot_type)

func _add_effect_id(effect_id: int, forced_slot_type: String = ""):
	var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
	if not effect or effect.factor == 0:
		_log_debug("Skipping effect_id=%d effect=%s factor=%s" % [effect_id, str(effect != null), str(effect.factor if effect else null)])
		return
	var slot_type_name = _normalize_equipment_type(forced_slot_type) if forced_slot_type != "" else effect.get_slot_string()
	_log_debug("Resolved effect_id=%d name=%s forced_slot=%s effect_slot_enum=%s effect_slot_string=%s" % [effect_id, effect.name, forced_slot_type, str(effect.slot), effect.get_slot_string()])
	if slot_type_name == "":
		slot_type_name = "Any"
	if not effect_groups.has(slot_type_name):
		effect_groups[slot_type_name] = []
		slot_type_order.append(slot_type_name)
	effect_groups[slot_type_name].append(effect)

func _select_default_slot_type_if_needed():
	if selected_slot_type != "" and effect_groups.has(selected_slot_type):
		return
	if working_item:
		var item_slot_type = _normalize_equipment_type(working_item.type)
		if effect_groups.has(item_slot_type):
			selected_slot_type = item_slot_type
			return
		if effect_groups.has("Any"):
			selected_slot_type = "Any"
			return
	selected_slot_type = slot_type_order[0] if not slot_type_order.is_empty() else ""

func _on_slot_type_selected(slot_type_name: String):
	if slot_type_name == selected_slot_type:
		populate_slot_type_toggles()
		return
	selected_slot_type = slot_type_name
	_return_item_if_type_mismatch()
	populate_slot_type_toggles()
	populate_effect_options()
	update_enchant_button_state()

func _get_slot_type_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for button in [slot_type_button_1, slot_type_button_2, slot_type_button_3, slot_type_button_4]:
		if button:
			buttons.append(button)
	return buttons

func _on_slot_type_button_pressed(button: Button):
	var slot_type_name = str(button.get_meta("slot_type_name", ""))
	_log_debug("toggle pressed text=%s meta=%s" % [button.text, slot_type_name])
	if slot_type_name == "":
		populate_slot_type_toggles()
		return
	_on_slot_type_selected(slot_type_name)

func _return_item_if_type_mismatch():
	if not working_item:
		return
	var item_slot_type = _normalize_equipment_type(working_item.type)
	if selected_slot_type == "Any" or selected_slot_type == item_slot_type:
		return
	return_enchanter_item_to_bag()

func _get_enchanter_payload() -> Variant:
	if GameInfo.current_player and _payload_has_effect_entries(GameInfo.current_player.enchanter_effects):
		return GameInfo.current_player.enchanter_effects
	if _payload_has_effect_entries(GameInfo.last_player_enchanter_payload):
		return GameInfo.last_player_enchanter_payload
	return []

func _get_default_toggle_icon(index: int) -> Texture2D:
	var defaults = [
		SLOT_TYPE_ICONS.get("Head", null),
		SLOT_TYPE_ICONS.get("Chest", null),
		SLOT_TYPE_ICONS.get("Hands", null),
		SLOT_TYPE_ICONS.get("Weapon", null)
	]
	if index >= 0 and index < defaults.size():
		return defaults[index]
	return null

func _payload_has_effect_entries(payload: Variant) -> bool:
	if payload is Array:
		return not payload.is_empty()
	if payload is Dictionary:
		return not payload.is_empty()
	return false

func _apply_slot_type_button_style(button: Button, is_selected: bool):
	if not _slot_type_button_styles.has("normal"):
		_slot_type_button_styles = {
			"normal": _make_slot_type_style(Color(0.10, 0.09, 0.08, 0.86), Color(0.55, 0.43, 0.22, 0.95), 2),
			"hover": _make_slot_type_style(Color(0.18, 0.16, 0.13, 0.96), Color(0.84, 0.70, 0.38, 1.0), 2),
			"pressed": _make_slot_type_style(Color(0.22, 0.18, 0.12, 1.0), Color(1.0, 0.78, 0.32, 1.0), 3),
			"disabled": _make_slot_type_style(Color(0.06, 0.055, 0.05, 0.58), Color(0.34, 0.28, 0.18, 0.75), 1)
		}
	button.add_theme_stylebox_override("normal", _slot_type_button_styles["pressed"] if is_selected else _slot_type_button_styles["normal"])
	button.add_theme_stylebox_override("hover", _slot_type_button_styles["hover"])
	button.add_theme_stylebox_override("pressed", _slot_type_button_styles["pressed"])
	button.add_theme_stylebox_override("disabled", _slot_type_button_styles["disabled"])
	button.modulate = Color(1.0, 0.92, 0.68, 1.0) if is_selected else Color(0.82, 0.78, 0.70, 1.0)

func _make_slot_type_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style

func _reload_effects_db():
	_did_refresh_effects_db = true
	if DataManager and DataManager.has_method("_load_effects_database"):
		DataManager.effects_db = DataManager._load_effects_database()
		GameInfo.effects_db = DataManager.effects_db
		_log_debug("effects_db reloaded from DataManager")
	else:
		_log_debug("Unable to reload effects_db from DataManager")

func _describe_effect_groups() -> String:
	var parts: Array[String] = []
	for slot_type_name in slot_type_order:
		var effect_names: Array[String] = []
		for effect in effect_groups.get(slot_type_name, []):
			effect_names.append("%s(%d)" % [effect.name, effect.id])
		parts.append("%s=[%s]" % [slot_type_name, ", ".join(effect_names)])
	return "; ".join(parts)

func _log_debug(message: String):
	if DEBUG_ENCHANTER:
		print("[EnchanterPanel] %s" % message)

func _on_effect_selected(effect_id: int, factor: float, option):
	selected_effect_id = effect_id
	selected_effect_factor = factor
	var effect = GameInfo.effects_db.get_effect_by_id(effect_id) if GameInfo.effects_db else null
	_set_effect_description(effect)
	
	for child in effect_list.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child == option)
	
	update_enchant_button_state()

func _set_effect_description(effect: EffectResource):
	if not effect_description:
		return
	if not effect:
		effect_description.text = ""
		return
	effect_description.text = EFFECT_FORMATTER.format_with_factor(effect.description, effect.factor, true)

func _get_effect_title(effect: EffectResource) -> String:
	if effect.name != "":
		return effect.name
	return EFFECT_FORMATTER.format_with_factor(effect.description, effect.factor, true)

func _normalize_equipment_type(raw_type: String) -> String:
	var t = raw_type.to_lower()
	match t:
		"head":
			return "Head"
		"chest":
			return "Chest"
		"hand", "hands":
			return "Hands"
		"foot", "feet":
			return "Foot"
		"belt":
			return "Belt"
		"leg", "legs":
			return "Legs"
		"ring", "back":
			return "Ring"
		"amulet":
			return "Amulet"
		"weapon":
			return "Weapon"
		"any":
			return "Any"
		_:
			return raw_type

func _on_enchant_pressed():
	if not working_item or selected_effect_id == 0:
		return
	
	# Send enchant request to server with the item's actual bag_slot_id
	Websocket.enchant_item(working_item.bag_slot_id, selected_effect_id)
	
	# Apply enchant instantly on client (rollback later if server rejects)
	working_item.effect_overdrive = selected_effect_id
	UIManager.instance.update_silver(-ENCHANT_COST)
	
	_show_greeting(on_action_greetings)
	
	# Clear the slot and return item to bag visually
	if enchanter_slot.has_method("clear_slot"):
		enchanter_slot.clear_slot()
	working_item = null
	selected_effect_id = 0
	selected_effect_factor = 0.0
	populate_effect_list()
	update_enchant_button_state()
	UIManager.instance.refresh_bags()
	UIManager.instance.refresh_stats()

func hide_panel():
	"""Explicitly hide panel and clean up"""
	return_enchanter_item_to_bag()
	visible = false
