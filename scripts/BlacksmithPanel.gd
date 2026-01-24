extends Panel

# BlacksmithPanel-specific functionality

# Slot numbering constants
const BLACKSMITH_SLOT = 16
const BAG_MIN = 10
const BAG_MAX = 14

@export var utility_background_container: Control  # Container to load utility background scene into
@export var bag: Control
@export var blacksmith_slot: Control
@export var improved_stats_label: Label
@export var temper_button: Button

var utility_background: UtilityBackground  # Found from loaded utility scene
var working_item: GameInfo.Item = null  # Reference to item being worked on (doesn't change bag_slot_id)

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
	utility_background.show_item_placed_greeting()

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
		utility_background.show_entered_greeting()

func _load_location_content():
	var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location)
	
	# Clear existing utility background
	for child in utility_background_container.get_children():
		child.queue_free()
	
	# Load and instance the utility background scene for this location
	var utility_scene = location_data.blacksmith_utility_scene
	var instance = utility_scene.instantiate()
	utility_background_container.add_child(instance)
	
	# Set to fill container
	instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	instance.offset_left = 0
	instance.offset_top = 0
	instance.offset_right = 0
	instance.offset_bottom = 0
	
	# Get reference to the utility background script
	utility_background = instance


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
	utility_background.show_action_greeting()
	
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
