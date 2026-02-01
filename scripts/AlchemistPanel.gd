extends TextureRect

const BREW_COST = 10

# Ingredient slot IDs
const SLOT_1 = 17
const SLOT_2 = 18
const SLOT_3 = 19
const BAG_MIN = 10
const BAG_MAX = 14

# Node references
@export var chat_bubble: ChatBubble
@export var bag: Control
@export var result_preview: Label
@export var brew_button: Button
@export var ingredient_slot1: Control
@export var ingredient_slot2: Control
@export var ingredient_slot3: Control

var on_entered_greetings: Array[String] = []
var on_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []
var working_items: Dictionary = {}  # Maps alchemist slot (17-19) -> GameInfo.Item reference

func _ready():
	brew_button.pressed.connect(_on_brew_button_pressed)
	visibility_changed.connect(_on_visibility_changed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	update_brew_button_state()

func on_item_placed_in_slot(slot_id: int, item: GameInfo.Item, _source_slot_id: int):
	"""Called when an item is placed in a specific alchemist slot (item keeps its original bag_slot_id)"""
	print("DEBUG AlchemistPanel.on_item_placed_in_slot: slot=", slot_id, " item=", item.item_name, " bag_slot_id=", item.bag_slot_id)
	working_items[slot_id] = item
	update_result_preview()
	update_brew_button_state()
	_show_greeting(on_placed_greetings)

func on_item_removed_from_slot(slot_id: int):
	"""Called when an item is removed from a specific alchemist slot"""
	print("DEBUG AlchemistPanel.on_item_removed_from_slot: slot=", slot_id)
	working_items.erase(slot_id)
	update_result_preview()
	update_brew_button_state()

func on_slot_changed(slot_id: int):
	"""Legacy - Called by UIManager when a utility slot changes (for compatibility)"""
	print("DEBUG AlchemistPanel.on_slot_changed called with slot_id=", slot_id)
	# This is now handled by on_item_placed_in_slot/on_item_removed_from_slot
	pass

func _on_visibility_changed():
	if not visible:
		return_ingredients_to_bag()
		working_items.clear()
	else:
		update_result_preview()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location) if GameInfo.settlements_db else null
	if not settlement:
		print("Error: No settlement found for location ", GameInfo.current_player.location)
		return
	
	# Apply utility texture directly to self
	if settlement.utility_texture:
		texture = settlement.utility_texture
	
	# Load utility greetings from settlement
	on_entered_greetings = settlement.get_utility_on_entered_lines()
	on_placed_greetings = settlement.get_utility_on_placed_lines()
	on_action_greetings = settlement.get_utility_on_action_lines()

func _show_greeting(greetings: Array[String]):
	if not chat_bubble or greetings.is_empty():
		return
	var greeting = greetings[randi() % greetings.size()]
	chat_bubble.show_with_text(greeting, 4.0)

func return_ingredients_to_bag():
	# Just clear the visual slots - items never actually moved
	working_items.clear()
	
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	for container in slot_containers:
		container.clear_slot()
	
	UIManager.instance.refresh_bags()

func get_ingredient_in_slot(slot_id: int) -> GameInfo.Item:
	# Use working_items dictionary instead of searching bag_slots by slot_id
	return working_items.get(slot_id, null)

func update_result_preview():
	var effects = []
	var effect_map = {}  # Map effect_id to total factor
	
	# Check all three ingredient slots
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			# Get item resource from database
			var item_resource = GameInfo.items_db.get_item_by_id(item.id)
			if item_resource and item_resource.effect_id > 0:
				# Add factor to existing effect or create new entry
				if effect_map.has(item_resource.effect_id):
					effect_map[item_resource.effect_id] += item_resource.effect_factor
				else:
					effect_map[item_resource.effect_id] = item_resource.effect_factor
	
	# Build effect text from combined effects
	for effect_id in effect_map.keys():
		var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
		if effect:
			var effect_text = effect.description
			if effect_map[effect_id] > 0:
				effect_text += " " + str(effect_map[effect_id])
			effects.append(effect_text)
	
	# Update preview label
	if effects.size() > 0:
		result_preview.text = "Elixir Effects:\n" + "\n".join(effects)
		result_preview.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6, 1))
	else:
		result_preview.text = "Elixir Effects: None"
		result_preview.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))

func update_brew_button_state():
	# Check if we have at least one ingredient
	var has_ingredients = false
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		if get_ingredient_in_slot(slot_id):
			has_ingredients = true
			break
	
	# Check if we have enough gold
	var has_silver = GameInfo.current_player.silver >= BREW_COST
	
	# Enable button only if both conditions are met
	brew_button.disabled = not (has_ingredients and has_silver)

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
	
	var items_to_brew = []
	var original_slots = []
	
	# Get items from working_items - they still have their original bag_slot_id
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = working_items.get(slot_id, null)
		if item:
			items_to_brew.append(item)
			original_slots.append(item.bag_slot_id)  # Use the item's actual bag_slot_id
	
	if items_to_brew.is_empty():
		return
	
	# Send WebSocket with original bag slot IDs (10-14)
	if original_slots.size() == 1:
		Websocket.brew_elixir(original_slots[0])
	elif original_slots.size() == 2:
		Websocket.brew_elixir(original_slots[0], original_slots[1])
	else:
		Websocket.brew_elixir(original_slots[0], original_slots[1], original_slots[2])
	
	# Client-side simulation
	UIManager.instance.update_silver(-BREW_COST)
	
	var ingredient_ids = []
	for item in items_to_brew:
		ingredient_ids.append(item.id)
	
	var new_elixir = GameInfo.Item.new({
		"id": 1000,
		"bag_slot_id": find_empty_bag_slot(),
		"ingredients": ingredient_ids
	})
	GameInfo.current_player.bag_slots.append(new_elixir)
	
	for item in items_to_brew:
		GameInfo.current_player.bag_slots.erase(item)
	
	# Clear tracking
	working_items.clear()
	
	clear_ingredient_slots()
	_show_greeting(on_action_greetings)
	UIManager.instance.refresh_bags()

func clear_ingredient_slots():
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	for container in slot_containers:
		container.clear_slot()

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
