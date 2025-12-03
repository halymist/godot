@tool
extends "res://scripts/UtilityPanel.gd"

# BlacksmithPanel-specific functionality can be added here
# For now, it uses all functionality from UtilityPanel

@onready var blacksmith_slot = $ItemsPanel/Content/ItemAndStats/ItemSlotContainer/ItemSlot/ItemContainer
@onready var current_stats_label = $ItemsPanel/Content/ItemAndStats/StatsContainer/CurrentStats
@onready var improved_stats_label = $ItemsPanel/Content/ItemAndStats/StatsContainer/ImprovedStats

func _ready():
	super._ready()
	# Connect to visibility changes to handle cleanup
	if not Engine.is_editor_hint():
		visibility_changed.connect(_on_visibility_changed)
		GameInfo.bag_slots_changed.connect(_on_item_changed)

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
		update_stats_display()

func update_stats_display():
	# Find item in slot 100
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 100:
			item_in_slot = item
			break
	
	if item_in_slot:
		# Display current stats
		var current_text = ""
		if item_in_slot.get("strength") and item_in_slot.strength > 0:
			current_text += "Strength: " + str(item_in_slot.strength) + "\n"
		if item_in_slot.get("stamina") and item_in_slot.stamina > 0:
			current_text += "Stamina: " + str(item_in_slot.stamina) + "\n"
		if item_in_slot.get("agility") and item_in_slot.agility > 0:
			current_text += "Agility: " + str(item_in_slot.agility) + "\n"
		if item_in_slot.get("luck") and item_in_slot.luck > 0:
			current_text += "Luck: " + str(item_in_slot.luck) + "\n"
		if item_in_slot.get("armor") and item_in_slot.armor > 0:
			current_text += "Armor: " + str(item_in_slot.armor) + "\n"
		
		current_stats_label.text = current_text if current_text != "" else "No stats"
		
		# Display improved stats (+10%)
		var improved_text = ""
		if item_in_slot.get("strength") and item_in_slot.strength > 0:
			var improved = int(item_in_slot.strength * 1.1)
			improved_text += "Strength: " + str(improved) + " (+" + str(improved - item_in_slot.strength) + ")\n"
		if item_in_slot.get("stamina") and item_in_slot.stamina > 0:
			var improved = int(item_in_slot.stamina * 1.1)
			improved_text += "Stamina: " + str(improved) + " (+" + str(improved - item_in_slot.stamina) + ")\n"
		if item_in_slot.get("agility") and item_in_slot.agility > 0:
			var improved = int(item_in_slot.agility * 1.1)
			improved_text += "Agility: " + str(improved) + " (+" + str(improved - item_in_slot.agility) + ")\n"
		if item_in_slot.get("luck") and item_in_slot.luck > 0:
			var improved = int(item_in_slot.luck * 1.1)
			improved_text += "Luck: " + str(improved) + " (+" + str(improved - item_in_slot.luck) + ")\n"
		if item_in_slot.get("armor") and item_in_slot.armor > 0:
			var improved = int(item_in_slot.armor * 1.1)
			improved_text += "Armor: " + str(improved) + " (+" + str(improved - item_in_slot.armor) + ")\n"
		
		improved_stats_label.text = improved_text if improved_text != "" else "No stat improvements"
	else:
		# No item in slot
		current_stats_label.text = "No item selected"
		improved_stats_label.text = "+10% to all stats"

func return_blacksmith_item_to_bag():
	# Find any item in slot 100 (blacksmith slot) and return it to an available bag slot
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
			
			# If no bag slot available, put it in the first bag slot (force it)
			item.bag_slot_id = 10
			# Clear the blacksmith slot visually
			if blacksmith_slot and blacksmith_slot.has_method("clear_slot"):
				blacksmith_slot.clear_slot()
			GameInfo.bag_slots_changed.emit()
			return
