extends Panel

# BlacksmithPanel-specific functionality

@export var background_rect: TextureRect
@export var description_label: Label
@export var bag: Control
@export var blacksmith_slot: Control
@export var improved_stats_label: Label
@export var temper_button: Button

const TEMPER_COST = 10

func _ready():
	_load_location_content()
	# Connect to visibility changes to handle cleanup
	visibility_changed.connect(_on_visibility_changed)
	GameInfo.bag_slots_changed.connect(_on_item_changed)
	if temper_button:
		temper_button.pressed.connect(_on_temper_pressed)
	update_temper_button_state()
	# Connect to layout mode changes
	print("BlacksmithPanel: connecting to layout_mode_changed signal")
	UIManager.instance.resolution_manager.layout_mode_changed.connect(_on_layout_mode_changed)

func _on_layout_mode_changed(is_wide: bool):
	print("BlacksmithPanel: layout mode changed, is_wide=", is_wide)
	if bag:
		bag.visible = not is_wide

func _on_visibility_changed():
	# When panel is hidden, return item from blacksmith slot to bag
	if not visible:
		return_blacksmith_item_to_bag()
	else:
		update_stats_display()

func _load_location_content():
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	if background_rect and location_data.blacksmith_background:
		background_rect.texture = location_data.blacksmith_background
	if description_label:
		description_label.text = location_data.get_random_blacksmith_greeting()

func _on_item_changed():
	# Update stats when item changes
	if visible:
		update_stats_display()

func update_stats_display():
	# Find item in slot 100
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 100:
			item_in_slot = item
			break
	
	if item_in_slot:
		# Display stats showing what they will be after one more tempering
		# Current stats already include existing tempering from database
		var stats_text = ""
		if item_in_slot.get("strength") and item_in_slot.strength > 0:
			var current = item_in_slot.strength
			var bonus = ceil(current * 0.1)
			var improved = current + bonus
			stats_text += "Strength: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if item_in_slot.get("stamina") and item_in_slot.stamina > 0:
			var current = item_in_slot.stamina
			var bonus = ceil(current * 0.1)
			var improved = current + bonus
			stats_text += "Stamina: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if item_in_slot.get("agility") and item_in_slot.agility > 0:
			var current = item_in_slot.agility
			var bonus = ceil(current * 0.1)
			var improved = current + bonus
			stats_text += "Agility: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if item_in_slot.get("luck") and item_in_slot.luck > 0:
			var current = item_in_slot.luck
			var bonus = ceil(current * 0.1)
			var improved = current + bonus
			stats_text += "Luck: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		if item_in_slot.get("armor") and item_in_slot.armor > 0:
			var current = item_in_slot.armor
			var bonus = ceil(current * 0.1)
			var improved = current + bonus
			stats_text += "Armor: " + str(current) + " + " + str(bonus) + " --> " + str(improved) + "\n"
		
		improved_stats_label.text = stats_text if stats_text != "" else "No stat improvements"
	else:
		# No item in slot
		improved_stats_label.text = "+10% to all stats"
	
	update_temper_button_state()

func return_blacksmith_item_to_bag():
	# Find any item in slot 100 (blacksmith slot) and return it to first available bag slot
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 100:
			# Find first available bag slot (10-14)
			for slot_id in range(10, 15):
				var slot_occupied = false
				for check_item in GameInfo.current_player.bag_slots:
					if check_item.bag_slot_id == slot_id:
						slot_occupied = true
						break
				
				if not slot_occupied:
					# Move item back to this bag slot
					item.bag_slot_id = slot_id
					# Clear the blacksmith slot visually
					if blacksmith_slot and blacksmith_slot.has_method("clear_slot"):
						blacksmith_slot.clear_slot()
					GameInfo.bag_slots_changed.emit()
					return

func update_temper_button_state():
	
	# Check if there's an item in the blacksmith slot
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 100:
			item_in_slot = item
			break
	
	# Button is enabled only if there's an item and player has enough gold
	var has_item = item_in_slot != null
	var has_silver = GameInfo.current_player.silver >= TEMPER_COST
	temper_button.disabled = not (has_item and has_silver)

func _on_temper_pressed():
	# Find item in slot 100
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 100:
			item_in_slot = item
			break
	
	if not item_in_slot:
		return
	
	# Check if player has enough silver
	if GameInfo.current_player.silver < TEMPER_COST:
		return
	
	# Deduct silver
	UIManager.instance.update_silver(-TEMPER_COST)
	update_temper_button_state()
	
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
	for slot_id in range(10, 15):
		var slot_occupied = false
		for check_item in GameInfo.current_player.bag_slots:
			if check_item.bag_slot_id == slot_id:
				slot_occupied = true
				break
		
		if not slot_occupied:
			item_in_slot.bag_slot_id = slot_id
			# Clear the blacksmith slot visually
			if blacksmith_slot and blacksmith_slot.has_method("clear_slot"):
				blacksmith_slot.clear_slot()
			break
	
	# Emit signal to update UI
	GameInfo.bag_slots_changed.emit()
	
	# Update stats display
	update_stats_display()
