extends TextureRect

const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")

const BREW_COST = 10
const COLOR_PRICE_NORMAL = Color(0.85, 0.8, 0.7, 1.0)
const COLOR_PRICE_MISSING = Color(1.0, 0.25, 0.2, 1.0)

# Ingredient slot IDs
const SLOT_1 = 17
const SLOT_2 = 18
const BAG_MIN = 10
const BAG_MAX = 14

# Node references
@export var chat_bubble: ChatBubble
@export var image_area: TextureRect
@export var bag: Control
@export var brew_button: Button
@export var ingredient_slot1: Control
@export var ingredient_slot2: Control
@export var ingredient_description1: Label
@export var ingredient_description2: Label

var on_entered_greetings: Array[String] = []
var on_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []
var working_items: Dictionary = {}  # Maps alchemist slot (17-18) -> GameInfo.Item reference

func _ready():
	brew_button.pressed.connect(_on_brew_button_pressed)
	visibility_changed.connect(_on_visibility_changed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	_update_ingredient_descriptions()
	update_brew_button_state()

func on_item_placed_in_slot(slot_id: int, item: GameInfo.Item, _source_slot_id: int):
	"""Called when an item is placed in a specific alchemist slot (item keeps its original bag_slot_id)"""
	working_items[slot_id] = item
	_update_ingredient_descriptions()
	update_brew_button_state()
	_show_greeting(on_placed_greetings)

func on_item_removed_from_slot(slot_id: int):
	"""Called when an item is removed from a specific alchemist slot"""
	working_items.erase(slot_id)
	_update_ingredient_descriptions()
	update_brew_button_state()

func on_slot_changed(_slot_id: int):
	"""Legacy - Called by UIManager when a utility slot changes (for compatibility)"""
	# This is now handled by on_item_placed_in_slot/on_item_removed_from_slot
	pass

func _on_visibility_changed():
	if not visible:
		return_ingredients_to_bag()
		working_items.clear()
	else:
		_update_ingredient_descriptions()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location) if GameInfo.settlements_db else null
	if not settlement:
		return
	
	var utility_texture = settlement.get_utility_texture()
	if utility_texture:
		if image_area:
			image_area.texture = utility_texture
			texture = null
		else:
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

func return_ingredients_to_bag():
	# Just clear the visual slots - items never actually moved
	working_items.clear()
	
	var slot_containers = [ingredient_slot1, ingredient_slot2]
	for container in slot_containers:
		container.clear_slot()
	_update_ingredient_descriptions()
	
	UIManager.instance.refresh_bags()

func get_ingredient_in_slot(slot_id: int) -> GameInfo.Item:
	# Use working_items dictionary instead of searching bag_slots by slot_id
	return working_items.get(slot_id, null)

func _update_ingredient_descriptions():
	_set_ingredient_description(ingredient_description1, SLOT_1, "Ingredient 1")
	_set_ingredient_description(ingredient_description2, SLOT_2, "Ingredient 2")

func _set_ingredient_description(label: Label, slot_id: int, empty_text: String):
	if not label:
		return

	var item = get_ingredient_in_slot(slot_id)
	if not item:
		label.text = empty_text
		label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
		return

	var item_resource = GameInfo.items_db.get_item_by_id(item.id) if GameInfo.items_db else null
	if not item_resource or item_resource.effect_id <= 0:
		label.text = item.item_name if item.item_name != "" else empty_text
		label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6, 1))
		return

	var effect = GameInfo.effects_db.get_effect_by_id(item_resource.effect_id) if GameInfo.effects_db else null
	if not effect:
		label.text = item.item_name if item.item_name != "" else empty_text
		label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6, 1))
		return

	var effect_text = EFFECT_FORMATTER.format_with_factor(effect.description, float(item_resource.effect_factor))
	if item_resource.effect_factor > 0 and effect_text == effect.description:
		effect_text += " " + str(int(item_resource.effect_factor))
	label.text = effect_text
	label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6, 1))

func update_brew_button_state():
	# Brewing now requires exactly two ingredients: one in each slot.
	var has_ingredients = get_ingredient_in_slot(SLOT_1) != null and get_ingredient_in_slot(SLOT_2) != null
	
	# Check if we have enough gold
	var has_silver = GameInfo.current_player.silver >= BREW_COST
	
	# Enable button only if both conditions are met
	brew_button.disabled = not (has_ingredients and has_silver)
	_set_price_label_color(brew_button, has_silver)

func _set_price_label_color(button: Button, can_afford: bool):
	var price_label = button.get_node_or_null("Content/PriceLabel") as Label
	if price_label:
		price_label.add_theme_color_override("font_color", COLOR_PRICE_NORMAL if can_afford else COLOR_PRICE_MISSING)

func get_working_items() -> Array[GameInfo.Item]:
	"""Return all items currently in the alchemy slots (for excluding from bag refresh)"""
	var items: Array[GameInfo.Item] = []
	for item in working_items.values():
		if item:
			items.append(item)
	return items

func _on_brew_button_pressed():
	if GameInfo.current_player.silver < BREW_COST:
		return

	var first_item = get_ingredient_in_slot(SLOT_1)
	var second_item = get_ingredient_in_slot(SLOT_2)
	if first_item == null or second_item == null:
		return
	
	var items_to_brew = []
	var original_slots = []
	
	# Get items from working_items - they still have their original bag_slot_id
	for slot_id in [SLOT_1, SLOT_2]:
		var item = working_items.get(slot_id, null)
		if item:
			items_to_brew.append(item)
			original_slots.append(item.bag_slot_id)  # Use the item's actual bag_slot_id
	
	if items_to_brew.size() != 2:
		return
	
	# Send WebSocket with both original bag slot IDs (10-14)
	Websocket.brew_elixir(original_slots[0], original_slots[1])

	var ingredient_ids = []
	for item in items_to_brew:
		ingredient_ids.append(item.id)

	var elixir_template = _get_elixir_template()
	if elixir_template == null:
		return

	# Client-side simulation
	UIManager.instance.update_silver(-BREW_COST)
	
	var new_elixir = GameInfo.Item.new({
		"id": elixir_template.id,
		"bag_slot_id": find_empty_bag_slot(),
		"ingredients": ingredient_ids
	})
	GameInfo.current_player.bag_slots.append(new_elixir)
	
	for item in items_to_brew:
		GameInfo.current_player.bag_slots.erase(item)
	
	# Clear tracking
	working_items.clear()
	
	clear_ingredient_slots()
	_update_ingredient_descriptions()
	update_brew_button_state()
	_show_greeting(on_action_greetings)
	UIManager.instance.refresh_bags()

func clear_ingredient_slots():
	var slot_containers = [ingredient_slot1, ingredient_slot2]
	for container in slot_containers:
		container.clear_slot()

func _get_elixir_template() -> ItemResource:
	if not GameInfo.items_db:
		return null

	for item_resource in GameInfo.items_db.items:
		if item_resource and item_resource.type == ItemResource.ItemType.ELIXIR:
			return item_resource

	return null

func find_empty_bag_slot() -> int:
	# Find first empty slot in bag
	var occupied_slots = []
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX:
			occupied_slots.append(item.bag_slot_id)
	
	for i in range(BAG_MIN, BAG_MAX + 1):
		if not i in occupied_slots:
			return i
	
	return BAG_MIN  # Fallback to first bag slot if all full
