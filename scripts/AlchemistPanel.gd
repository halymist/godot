extends Panel

const BREW_COST = 10

# Ingredient slot IDs
const SLOT_1 = 101
const SLOT_2 = 102
const SLOT_3 = 103

# Node references
@export var background_rect: TextureRect
@export var result_preview: Label
@export var brew_button: Button
@export var ingredient_slot1: Control
@export var ingredient_slot2: Control
@export var ingredient_slot3: Control

func _ready():
	_load_location_content()
	# Connect to visibility changes to handle cleanup
	visibility_changed.connect(_on_visibility_changed)
	# Connect brew button
	brew_button.pressed.connect(_on_brew_button_pressed)
	# Connect to gold and bag changes to update UI
	GameInfo.gold_changed.connect(_on_gold_changed)
	GameInfo.bag_slots_changed.connect(_on_bag_slots_changed)

func _on_visibility_changed():
	# When panel is hidden, return items from ingredient slots to bag
	if not visible:
		return_ingredients_to_bag()
	else:
		update_result_preview()

func _load_location_content():
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	if background_rect and location_data.alchemist_background:
		background_rect.texture = location_data.alchemist_background

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
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	
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
	var has_gold = GameInfo.current_player.gold >= BREW_COST
	
	# Enable button only if both conditions are met
	brew_button.disabled = not (has_ingredients and has_gold)

func _on_brew_button_pressed():
	# Check gold
	if GameInfo.current_player.gold < BREW_COST:
		return
	
	# Collect ingredient IDs from the slots
	var ingredient_ids = [0, 0, 0]
	var slot_index = 0
	
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			ingredient_ids[slot_index] = item.id
		slot_index += 1
	
	# Check if we have at least one ingredient
	if ingredient_ids[0] == 0 and ingredient_ids[1] == 0 and ingredient_ids[2] == 0:
		return
	
	# Generate encoded elixir ID using string concatenation
	# Format: "1000" + ingredient1_id(3 digits) + ingredient2_id(3 digits) + ingredient3_id(3 digits)
	var id_str = "1000"
	for ingredient_id in ingredient_ids:
		id_str += str(ingredient_id).pad_zeros(3)  # Pad each ID to 3 digits
	
	var encoded_id = int(id_str)
	
	print("Brewing elixir with ID: ", encoded_id)
	print("  Ingredient IDs: ", ingredient_ids)
	
	# Deduct gold
	GameInfo.current_player.gold -= BREW_COST
	GameInfo.gold_changed.emit(GameInfo.current_player.gold)
	
	# Create new elixir item and add to first available bag slot
	var new_elixir = GameInfo.Item.new()
	new_elixir.id = encoded_id
	new_elixir.bag_slot_id = find_empty_bag_slot()
	
	# Manually load elixir base data since _init might not have access to GameInfo yet
	var base_elixir = GameInfo.items_db.get_item_by_id(1000)
	if base_elixir:
		new_elixir.item_name = base_elixir.item_name
		new_elixir.type = base_elixir.type
		new_elixir.texture = base_elixir.icon
		print("Elixir created: ", new_elixir.item_name, " with texture: ", new_elixir.texture != null)
	
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
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	
	for container in slot_containers:
		if container and container.has_method("clear_slot"):
			container.clear_slot()

func find_empty_bag_slot() -> int:
	# Find first empty slot in bag (slots 10-14, the visible bag slots)
	var occupied_slots = []
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id >= 10 and item.bag_slot_id <= 14:
			occupied_slots.append(item.bag_slot_id)
	
	for i in range(10, 15):
		if not i in occupied_slots:
			return i
	
	return 10  # Fallback to slot 10 if all full

func _on_gold_changed(_new_gold: int):
	update_brew_button_state()

func _on_bag_slots_changed():
	update_slot_visuals()
	update_result_preview()
	update_brew_button_state()

func update_slot_visuals():
	# Update ingredient slots 101-103
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	var slot_ids = [101, 102, 103]
	
	for i in range(3):
		var container = slot_containers[i]
		if container and container.has_method("clear_slot"):
			container.clear_slot()
			
			# Find item in this slot
			for item in GameInfo.current_player.bag_slots:
				if item.bag_slot_id == slot_ids[i]:
					# Get item prefab from the bag
					var bag = get_node_or_null("Bag")
					if bag and bag.item_prefab:
						var icon = bag.item_prefab.instantiate()
						icon.set_item_data(item)
						container.add_child(icon)
					break
			
			container.update_slot_appearance()
