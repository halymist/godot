extends Panel

const BREW_COST = 10

# Ingredient slot IDs
const SLOT_1 = 17
const SLOT_2 = 18
const SLOT_3 = 19
const BAG_MIN = 10
const BAG_MAX = 14

# Node references
@export var utility_background_container: Control
@export var bag: Control
@export var result_preview: Label
@export var brew_button: Button
@export var ingredient_slot1: Control
@export var ingredient_slot2: Control
@export var ingredient_slot3: Control

var utility_background: UtilityBackground  # Found from loaded utility scene

func _ready():
	_load_location_content()

	visibility_changed.connect(_on_visibility_changed)
	brew_button.pressed.connect(_on_brew_button_pressed)

func on_slot_changed(slot_id: int):
	"""Called by UIManager when a utility slot changes"""
	if slot_id >= SLOT_1 and slot_id <= SLOT_3:
		update_result_preview()
		update_brew_button_state()
		# Show item placed greeting when ingredient is added
		if utility_background:
			utility_background.show_item_placed_greeting()

func _on_visibility_changed():
	# When panel is hidden, return items from ingredient slots to bag
	if not visible:
		return_ingredients_to_bag()
	else:
		update_result_preview()
		# Show entered greeting when panel becomes visible
		if utility_background:
			utility_background.show_entered_greeting()

func _load_location_content():
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	
	# Clear existing children from container
	if utility_background_container:
		for child in utility_background_container.get_children():
			child.queue_free()
	
	# Instantiate and add the utility scene
	if location_data.alchemist_utility_scene:
		var utility_instance = location_data.alchemist_utility_scene.instantiate()
		utility_background_container.add_child(utility_instance)
		
		# Set to full rect (anchors 0,0 to 1,1 with zero offsets)
		if utility_instance is Control:
			utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
			utility_instance.offset_left = 0
			utility_instance.offset_top = 0
			utility_instance.offset_right = 0
			utility_instance.offset_bottom = 0
		
		# Get reference to the utility background script
		if utility_instance is UtilityBackground:
			utility_background = utility_instance
		else:
			utility_background = null

func return_ingredients_to_bag():
	# Return items from ingredient slots to bag
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == slot_id:
				# Find first available bag slot
				for bag_slot_id in range(BAG_MIN, BAG_MAX + 1):
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
	
	if UIManager.instance:
		UIManager.instance.refresh_bags()

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
	var has_silver = GameInfo.current_player.silver >= BREW_COST
	
	# Enable button only if both conditions are met
	brew_button.disabled = not (has_ingredients and has_silver)

func _on_brew_button_pressed():
	# Check gold
	if GameInfo.current_player.silver < BREW_COST:
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
	
	# Deduct silver
	UIManager.instance.update_silver(-BREW_COST)
	
	# Create new elixir item and add to first available bag slot
	var new_elixir = GameInfo.Item.new({
		"id": encoded_id,
		"bag_slot_id": find_empty_bag_slot()
	})
	
	# Elixirs use base texture from id 1000
	if not new_elixir.texture:
		var base_elixir_resource = GameInfo.items_db.get_item_by_id(1000)
		if base_elixir_resource:
			new_elixir.texture = base_elixir_resource.icon
	
	print("Elixir created with ID: ", new_elixir.id, " name: ", new_elixir.item_name)
	
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
	
	# Show action greeting after brewing
	if utility_background:
		utility_background.show_action_greeting()
	
	if UIManager.instance:
		UIManager.instance.refresh_bags()

func clear_ingredient_slots():
	# Clear all three ingredient slot visuals
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	
	for container in slot_containers:
		if container and container.has_method("clear_slot"):
			container.clear_slot()

func find_empty_bag_slot() -> int:
	# Find first empty slot in bag
	var occupied_slots = []
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX:
			occupied_slots.append(item.bag_slot_id)
	
	for i in range(BAG_MIN, BAG_MAX + 1):
		if not i in occupied_slots:
			return i
	
	return BAG_MIN  # Fallback to first bag slot if all full
