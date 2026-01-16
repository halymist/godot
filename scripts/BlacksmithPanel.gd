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
var original_bag_slot: int = -1  # Track where item came from

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

func on_slot_changed(slot_id: int):
	"""Called by UIManager when a utility slot changes"""
	if slot_id == BLACKSMITH_SLOT:
		# Track where item came from
		var item_in_slot = null
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == BLACKSMITH_SLOT:
				item_in_slot = item
				break
		if item_in_slot:
			# Find original slot (search bag slots 10-14)
			for check_slot in range(BAG_MIN, BAG_MAX + 1):
				var found = false
				for check_item in GameInfo.current_player.bag_slots:
					if check_item.bag_slot_id == check_slot and check_item != item_in_slot:
						found = true
						break
				if not found:
					original_bag_slot = check_slot
					break
		
		update_stats_display()
		update_temper_button_state()
		utility_background.show_item_placed_greeting()

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
	# Find item in blacksmith slot
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == BLACKSMITH_SLOT:
			item_in_slot = item
			break
	
	if item_in_slot:
		# Display stats showing what they will be after one more tempering
		# Get the item resource for base stats
		var res = item_in_slot.get_resource()
		if not res:
			improved_stats_label.text = "Error: No item resource"
			return
		
		var stats_text = ""
		var current_tempered = item_in_slot.tempered if item_in_slot.get("tempered") else 0
		var day = item_in_slot.day if item_in_slot.get("day") else 0
		
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
	# Find any item in blacksmith slot and return it to first available bag slot
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == BLACKSMITH_SLOT:
			# Find first available bag slot
			for slot_id in range(BAG_MIN, BAG_MAX + 1):
				var slot_occupied = false
				for check_item in GameInfo.current_player.bag_slots:
					if check_item.bag_slot_id == slot_id:
						slot_occupied = true
						break
				
				if not slot_occupied:
					# Move item back to this bag slot
					item.bag_slot_id = slot_id
					# Clear the blacksmith slot visually
					blacksmith_slot.clear_slot()
					# Notify all bag views to redraw
					UIManager.instance.refresh_bags()
					return

func update_temper_button_state():
	# Check if there's an item in the blacksmith slot
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == BLACKSMITH_SLOT:
			item_in_slot = item
			break
	
	# Button is enabled only if there's an item and player has enough gold
	var has_item = item_in_slot != null
	var has_silver = GameInfo.current_player.silver >= TEMPER_COST
	temper_button.disabled = not (has_item and has_silver)

func _on_temper_pressed():
	# Find item in blacksmith slot
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == BLACKSMITH_SLOT:
			item_in_slot = item
			break
	
	if not item_in_slot:
		return
	
	# Send temper request to server with original bag slot
	Websocket.temper_item(original_bag_slot)
	UIManager.instance.update_silver(-TEMPER_COST)
	update_temper_button_state()
	
	# Show action greeting
	utility_background.show_action_greeting()
	
	# Improve item stats by 10% (rounded up)
	if item_in_slot.get("strength") and item_in_slot.strength > 0:
		item_in_slot.strength += ceil(item_in_slot.strength * 0.1)
	if item_in_slot.get("stamina") and item_in_slot.stamina > 0:
		item_in_slot.stamina += ceil(item_in_slot.stamina * 0.1)
	if item_in_slot.get("agility") and item_in_slot.agility > 0:
		item_in_slot.agility += ceil(item_in_slot.agility * 0.1)
	if item_in_slot.get("luck") and item_in_slot.luck > 0:
		item_in_slot.luck += ceil(item_in_slot.luck * 0.1)
	if item_in_slot.get("armor") and item_in_slot.armor > 0:
		item_in_slot.armor += ceil(item_in_slot.armor * 0.1)
	
	# Mark item as tempered
	item_in_slot.tempered += 1
	
	# Move item back to bag after tempering
	for slot_id in range(BAG_MIN, BAG_MAX + 1):
		var slot_occupied = false
		for check_item in GameInfo.current_player.bag_slots:
			if check_item.bag_slot_id == slot_id:
				slot_occupied = true
				break
		
		if not slot_occupied:
			item_in_slot.bag_slot_id = slot_id
			# Clear the blacksmith slot visually
			blacksmith_slot.clear_slot()
			break
	
	# Update stats display
	update_stats_display()
	UIManager.instance.refresh_bags()
