extends TextureRect

# BlacksmithPanel-specific functionality

# Slot numbering constants
const BLACKSMITH_SLOT = 16
const BAG_MIN = 10
const BAG_MAX = 14

@export var chat_bubble: ChatBubble
@export var image_area: TextureRect
@export var bag: Control
@export var blacksmith_slot: Control
@export var improved_stats_label: Label
@export var temper_button: Button

var on_entered_greetings: Array[String] = []
var on_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []
var working_item: GameInfo.Item = null

const TEMPER_COST = 10
const COLOR_PRICE_NORMAL = Color(0.85, 0.8, 0.7, 1.0)
const COLOR_PRICE_MISSING = Color(1.0, 0.25, 0.2, 1.0)

func _ready():
	# Connect to visibility changes to handle cleanup
	visibility_changed.connect(_on_visibility_changed)
	temper_button.pressed.connect(_on_temper_pressed)
	
	# Wait for game to be ready
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	update_temper_button_state()

func on_item_placed(item: GameInfo.Item, _source_slot_id: int):
	"""Called when an item is placed in the blacksmith slot (item keeps its original bag_slot_id)"""
	working_item = item
	update_stats_display()
	update_temper_button_state()
	_show_greeting(on_placed_greetings)

func on_item_removed():
	"""Called when an item is removed from the blacksmith slot"""
	working_item = null
	update_stats_display()
	update_temper_button_state()

func on_slot_changed(_slot_id: int):
	"""Legacy - Called by UIManager when a utility slot changes (for compatibility)"""
	# This is now handled by on_item_placed/on_item_removed
	pass

func _on_visibility_changed():
	# When panel is hidden, return item from blacksmith slot to bag
	if not visible:
		return_blacksmith_item_to_bag()
	else:
		_load_location_content()
		update_stats_display()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
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

func update_stats_display():
	# Use working_item reference (item keeps its original bag_slot_id)
	if working_item:
		# Display stats showing what they will be after one more tempering
		# Get the item resource for base stats
		var res = working_item.get_resource()
		if not res:
			improved_stats_label.text = "Error: No item resource"
			return
		
		var stats_text = ""
		var current_tempered = working_item.tempered if working_item.get("tempered") else 0
		var day = working_item.day if working_item.get("day") else 0
		
		if res.strength > 0:
			var current = GameInfo.Item.calculate_scaled_value(res.strength, day, current_tempered)
			var improved = GameInfo.Item.calculate_scaled_value(res.strength, day, current_tempered + 1)
			var bonus = improved - current
			stats_text += "Strength: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if res.stamina > 0:
			var current = GameInfo.Item.calculate_scaled_value(res.stamina, day, current_tempered)
			var improved = GameInfo.Item.calculate_scaled_value(res.stamina, day, current_tempered + 1)
			var bonus = improved - current
			stats_text += "Stamina: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if res.agility > 0:
			var current = GameInfo.Item.calculate_scaled_value(res.agility, day, current_tempered)
			var improved = GameInfo.Item.calculate_scaled_value(res.agility, day, current_tempered + 1)
			var bonus = improved - current
			stats_text += "Agility: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if res.luck > 0:
			var current = GameInfo.Item.calculate_scaled_value(res.luck, day, current_tempered)
			var improved = GameInfo.Item.calculate_scaled_value(res.luck, day, current_tempered + 1)
			var bonus = improved - current
			stats_text += "Luck: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if res.armor > 0:
			var current = GameInfo.Item.calculate_scaled_value(res.armor, day, current_tempered)
			var improved = GameInfo.Item.calculate_scaled_value(res.armor, day, current_tempered + 1)
			var bonus = improved - current
			stats_text += "Armor: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if res.damage_min > 0:
			var current = GameInfo.Item.calculate_scaled_value(res.damage_min, day, current_tempered)
			var improved = GameInfo.Item.calculate_scaled_value(res.damage_min, day, current_tempered + 1)
			var bonus = improved - current
			stats_text += "Damage Min: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if res.damage_max > 0:
			var current = GameInfo.Item.calculate_scaled_value(res.damage_max, day, current_tempered)
			var improved = GameInfo.Item.calculate_scaled_value(res.damage_max, day, current_tempered + 1)
			var bonus = improved - current
			stats_text += "Damage Max: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		
		improved_stats_label.text = stats_text if stats_text != "" else "No stat improvements"
	else:
		# No item in slot
		improved_stats_label.text = "+10% to all stats"
	
	update_temper_button_state()

func return_blacksmith_item_to_bag():
	# Just clear the visual slot and reset working_item
	# The item never actually moved - it keeps its original bag_slot_id
	if working_item:
		working_item = null
		blacksmith_slot.clear_slot()
		UIManager.instance.refresh_bags()

func update_temper_button_state():
	# Check if there's a working item
	
	# Button is enabled only if there's an item and player has enough gold
	var has_item = working_item != null
	var has_silver = GameInfo.current_player.silver >= TEMPER_COST
	temper_button.disabled = not (has_item and has_silver)
	_set_price_label_color(temper_button, has_silver)

func _set_price_label_color(button: Button, can_afford: bool):
	var price_label = button.get_node_or_null("Content/PriceLabel") as Label
	if price_label:
		price_label.add_theme_color_override("font_color", COLOR_PRICE_NORMAL if can_afford else COLOR_PRICE_MISSING)

func _on_temper_pressed():
	if not working_item:
		return
	
	# Send temper request to server with the item's actual bag_slot_id
	Websocket.temper_item(working_item.bag_slot_id)
	
	# Apply temper instantly on client (rollback later if server rejects)
	working_item.tempered += 1
	UIManager.instance.update_silver(-TEMPER_COST)
	
	# Show action greeting
	_show_greeting(on_action_greetings)
	
	# Clear the slot and return item to bag visually
	blacksmith_slot.clear_slot()
	working_item = null
	update_stats_display()
	update_temper_button_state()
	UIManager.instance.refresh_bags()
	UIManager.instance.refresh_stats()

func get_working_item() -> GameInfo.Item:
	"""Return the item currently being worked on (for excluding from bag refresh)"""
	return working_item
