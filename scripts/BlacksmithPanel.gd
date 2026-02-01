extends TextureRect

# BlacksmithPanel-specific functionality

# Slot numbering constants
const BLACKSMITH_SLOT = 16
const BAG_MIN = 10
const BAG_MAX = 14

@export var chat_bubble: PackedScene
@export var bag: Control
@export var blacksmith_slot: Control
@export var improved_stats_label: Label
@export var temper_button: Button

var on_entered_greetings: Array[String] = []
var on_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []
var working_item: GameInfo.Item = null
var _chat_bubble_instance: ChatBubble = null  # Reference to item being worked on (doesn't change bag_slot_id)

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
	print("DEBUG BlacksmithPanel.on_item_placed: item=", item.item_name, " bag_slot_id=", item.bag_slot_id)
	working_item = item
	update_stats_display()
	update_temper_button_state()
	_show_greeting(on_placed_greetings)

func on_item_removed():
	"""Called when an item is removed from the blacksmith slot"""
	print("DEBUG BlacksmithPanel.on_item_removed")
	working_item = null
	update_stats_display()
	update_temper_button_state()

func on_slot_changed(slot_id: int):
	"""Legacy - Called by UIManager when a utility slot changes (for compatibility)"""
	print("DEBUG BlacksmithPanel.on_slot_changed called with slot_id=", slot_id)
	# This is now handled by on_item_placed/on_item_removed
	pass

func _on_visibility_changed():
	# When panel is hidden, return item from blacksmith slot to bag
	if not visible:
		return_blacksmith_item_to_bag()
	else:
		update_stats_display()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
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
	# Lazily instantiate chat bubble on first use
	if not _chat_bubble_instance:
		_chat_bubble_instance = chat_bubble.instantiate()
		add_child(_chat_bubble_instance)
		_chat_bubble_instance.anchors_preset = Control.PRESET_CENTER_TOP
		_chat_bubble_instance.position.y = 20
	var greeting = greetings[randi() % greetings.size()]
	_chat_bubble_instance.show_with_text(greeting, 4.0)


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
		print("DEBUG return_blacksmith_item_to_bag: clearing working_item")
		working_item = null
		blacksmith_slot.clear_slot()
		UIManager.instance.refresh_bags()

func update_temper_button_state():
	# Check if there's a working item
	print("DEBUG update_temper_button_state: working_item=", working_item)
	
	# Button is enabled only if there's an item and player has enough gold
	var has_item = working_item != null
	var has_silver = GameInfo.current_player.silver >= TEMPER_COST
	print("DEBUG: has_item=", has_item, " has_silver=", has_silver, " (silver=", GameInfo.current_player.silver, ")")
	temper_button.disabled = not (has_item and has_silver)
	print("DEBUG: temper_button.disabled=", temper_button.disabled)

func _on_temper_pressed():
	if not working_item:
		print("No working item to temper")
		return
	
	# Send temper request to server with the item's actual bag_slot_id
	print("DEBUG: Sending temper_item for slot ", working_item.bag_slot_id)
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
