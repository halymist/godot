@tool
extends "res://scripts/UtilityPanel.gd"

# BlacksmithPanel-specific functionality can be added here
# For now, it uses all functionality from UtilityPanel

@export var blacksmith_slot: Control
@export var improved_stats_label: Label
@export var temper_button: Button

const TEMPER_COST = 10

func _ready():
	super._ready()
	# Connect to visibility changes to handle cleanup
	if not Engine.is_editor_hint():
		visibility_changed.connect(_on_visibility_changed)
		GameInfo.bag_slots_changed.connect(_on_item_changed)
		GameInfo.gold_changed.connect(_on_gold_changed)
		if temper_button:
			temper_button.pressed.connect(_on_temper_pressed)
		update_temper_button_state()

func _on_gold_changed(_new_gold):
	# Update button state when gold changes
	update_temper_button_state()

func _on_visibility_changed():
	# When panel is hidden, return item from blacksmith slot to bag
	if not visible:
		return_blacksmith_item_to_bag()
	else:
		# When panel becomes visible, update stats display
		update_stats_display()

func _on_item_changed():
	# Update stats when item changes
	if visible:
		update_slot_visual()
		update_stats_display()

func update_slot_visual():
	# Update the visual display of slot 100
	if blacksmith_slot and blacksmith_slot.has_method("clear_slot"):
		blacksmith_slot.clear_slot()
		
		# Find item in slot 100
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == 100:
				# Get item prefab from the bag
				var bag = get_node_or_null("Bag")
				if bag and bag.item_prefab:
					var icon = bag.item_prefab.instantiate()
					icon.set_item_data(item)
					blacksmith_slot.add_child(icon)
				break
		
		blacksmith_slot.update_slot_appearance()

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
	if not temper_button:
		return
	
	# Check if there's an item in the blacksmith slot
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 100:
			item_in_slot = item
			break
	
	# Button is enabled only if there's an item and player has enough gold
	var has_item = item_in_slot != null
	var has_gold = GameInfo.current_player.gold >= TEMPER_COST
	temper_button.disabled = not (has_item and has_gold)

func _on_temper_pressed():
	# Find item in slot 100
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 100:
			item_in_slot = item
			break
	
	if not item_in_slot:
		return
	
	# Check if player has enough gold
	if GameInfo.current_player.gold < TEMPER_COST:
		return
	
	# Deduct gold
	GameInfo.current_player.gold -= TEMPER_COST
	GameInfo.gold_changed.emit(GameInfo.current_player.gold)
	
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
