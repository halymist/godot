@tool
extends "res://scripts/UtilityPanel.gd"

const BREW_COST = 10

# Ingredient slot IDs
const SLOT_1 = 101
const SLOT_2 = 102
const SLOT_3 = 103

# Node references
@onready var result_preview = $ItemsPanel/Content/ResultPreview
@onready var brew_button = $ItemsPanel/Content/BrewButton

func _ready():
	super._ready()
	
	if Engine.is_editor_hint():
		return
	
	# Connect to visibility changes to handle cleanup
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect brew button
	brew_button.pressed.connect(_on_brew_button_pressed)
	
	# Connect to gold and bag changes to update UI
	if GameInfo.gold_changed:
		GameInfo.gold_changed.connect(_on_gold_changed)
	if GameInfo.bag_slots_changed:
		GameInfo.bag_slots_changed.connect(_on_bag_slots_changed)
	
	update_brew_button_state()
	update_result_preview()

func _on_visibility_changed():
	# When panel is hidden, return items from ingredient slots to bag
	if not visible:
		return_ingredients_to_bag()
	else:
		# When panel becomes visible, update preview
		update_result_preview()

func return_ingredients_to_bag():
	# Return items from ingredient slots (101, 102, 103) to bag
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == slot_id:
				# Find first available bag slot (10-14)
				for bag_slot_id in range(10, 15):
					var slot_occupied = false
					for check_item in GameInfo.current_player.bag_slots:
						if check_item.bag_slot_id == bag_slot_id:
							slot_occupied = true
							break
					
					if not slot_occupied:
						# Move item back to this bag slot
						item.bag_slot_id = bag_slot_id
						break
				break
	
	# Clear the visual slots
	var slot_containers = [
		$ItemsPanel/Content/BrewingContainer/IngredientsRow/Slot1/SlotContainer,
		$ItemsPanel/Content/BrewingContainer/IngredientsRow/Slot2/SlotContainer,
		$ItemsPanel/Content/BrewingContainer/IngredientsRow/Slot3/SlotContainer
	]
	
	for container in slot_containers:
		if container and container.has_method("clear_slot"):
			container.clear_slot()
	
	GameInfo.bag_slots_changed.emit()

func get_ingredient_in_slot(slot_id: int) -> GameInfo.Item:
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == slot_id:
			return item
	return null

func update_result_preview():
	var effects = []
	
	# Check all three ingredient slots
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			# Get item resource from database
			var item_resource = GameInfo.items_db.get_item_by_id(item.id)
			if item_resource and item_resource.effect_id > 0:
				# Find effect in database
				var effect = GameInfo.effects_db.get_effect_by_id(item_resource.effect_id)
				if effect:
					var effect_text = effect.description
					if item_resource.effect_factor > 0:
						effect_text += " " + str(item_resource.effect_factor)
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
	var has_gold = GameInfo.current_player.gold >= BREW_COST
	
	# Enable button only if both conditions are met
	brew_button.disabled = not (has_ingredients and has_gold)

func _on_brew_button_pressed():
	# Check gold
	if GameInfo.current_player.gold < BREW_COST:
		return
	
	# Collect effect IDs and factors from ingredients
	var effect_ids = [0, 0, 0]
	var effect_factors = [0, 0, 0]
	var slot_index = 0
	
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			var item_resource = GameInfo.items_db.get_item_by_id(item.id)
			if item_resource and item_resource.effect_id > 0:
				effect_ids[slot_index] = item_resource.effect_id
				effect_factors[slot_index] = item_resource.effect_factor
		slot_index += 1
	
	# Check if we have at least one effect
	if effect_ids[0] == 0 and effect_ids[1] == 0 and effect_ids[2] == 0:
		return
	
	# Generate encoded elixir ID: 1000 + 9 digits (3 effect IDs, each 3 digits)
	# Format: 1000 + effectID1(3) + effectID2(3) + effectID3(3)
	var encoded_id = 1000000000000  # Base: 1000 with 9 zeros
	encoded_id += effect_ids[0] * 1000000  # First effect (digits 4-6)
	encoded_id += effect_ids[1] * 1000      # Second effect (digits 7-9)
	encoded_id += effect_ids[2]             # Third effect (digits 10-12)
	
	print("Brewing elixir with ID: ", encoded_id)
	print("  Effect IDs: ", effect_ids)
	print("  Effect Factors: ", effect_factors)
	
	# Deduct gold
	GameInfo.current_player.gold -= BREW_COST
	GameInfo.gold_changed.emit(GameInfo.current_player.gold)
	
	# Create new elixir item and add to first available bag slot
	var new_elixir = GameInfo.Item.new()
	new_elixir.id = encoded_id
	new_elixir.bag_slot_id = find_empty_bag_slot()
	
	# Add to player's bag
	GameInfo.current_player.bag_slots.append(new_elixir)
	
	# Remove ingredients from slots (they get consumed)
	var items_to_remove = []
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			items_to_remove.append(item)
	
	for item in items_to_remove:
		GameInfo.current_player.bag_slots.erase(item)
	
	# Clear the visual slots
	clear_ingredient_slots()
	
	GameInfo.bag_slots_changed.emit()

func clear_ingredient_slots():
	# Clear all three ingredient slot visuals
	var slot_containers = [
		$ItemsPanel/Content/BrewingContainer/IngredientsRow/Slot1/SlotContainer,
		$ItemsPanel/Content/BrewingContainer/IngredientsRow/Slot2/SlotContainer,
		$ItemsPanel/Content/BrewingContainer/IngredientsRow/Slot3/SlotContainer
	]
	
	for container in slot_containers:
		if container and container.has_method("clear_slot"):
			container.clear_slot()

func find_empty_bag_slot() -> int:
	# Find first empty slot in bag (slots 0-99)
	var occupied_slots = []
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id >= 0 and item.bag_slot_id < 100:
			occupied_slots.append(item.bag_slot_id)
	
	for i in range(100):
		if not i in occupied_slots:
			return i
	
	return 0  # Fallback to slot 0 if all full

func _on_gold_changed(_new_gold: int):
	update_brew_button_state()

func _on_bag_slots_changed():
	update_result_preview()
	update_brew_button_state()
