extends TextureRect

const UI_UTILS = preload("res://scripts/utils/UIUtils.gd")
const SETTLEMENT_UTILS = preload("res://scripts/utils/SettlementPanelUtils.gd")

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
	var content = SETTLEMENT_UTILS.load_utility_content(self, image_area, chat_bubble)
	if content.is_empty():
		return
	on_entered_greetings = content.get("entered", [])
	on_placed_greetings = content.get("placed", [])
	on_action_greetings = content.get("action", [])

func _show_greeting(greetings: Array[String]):
	SETTLEMENT_UTILS.show_greeting(chat_bubble, greetings)

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
	UI_UTILS.set_button_price_color(temper_button, has_silver)

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
