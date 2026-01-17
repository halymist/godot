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

var utility_background: UtilityBackground
var original_bag_slots: Dictionary = {}  # Maps alchemist slot (17-19) -> original bag slot (10-14)

func _ready():
	brew_button.pressed.connect(_on_brew_button_pressed)
	visibility_changed.connect(_on_visibility_changed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	update_brew_button_state()

func on_slot_changed(slot_id: int):
	if slot_id >= SLOT_1 and slot_id <= SLOT_3:
		# Track original bag slot where item came from
		var item_in_slot = null
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == slot_id:
				item_in_slot = item
				break
		
		if item_in_slot:
			# Find first empty bag slot - that's where it came from
			for check_slot in range(BAG_MIN, BAG_MAX + 1):
				var slot_occupied = false
				for check_item in GameInfo.current_player.bag_slots:
					if check_item.bag_slot_id == check_slot and check_item != item_in_slot:
						slot_occupied = true
						break
				
				if not slot_occupied:
					original_bag_slots[slot_id] = check_slot
					break
		
		update_result_preview()
		update_brew_button_state()
		utility_background.show_item_placed_greeting()

func _on_visibility_changed():
	if not visible:
		return_ingredients_to_bag()
		original_bag_slots.clear()
	else:
		update_result_preview()
		utility_background.show_entered_greeting()

func _load_location_content():
	var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location) if GameInfo.settlements_db else null
	
	for child in utility_background_container.get_children():
		child.queue_free()
	
	if location_data.alchemist_utility_scene:
		var utility_instance = location_data.alchemist_utility_scene.instantiate()
		utility_background_container.add_child(utility_instance)
		
		if utility_instance is Control:
			utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
			utility_instance.offset_left = 0
			utility_instance.offset_top = 0
			utility_instance.offset_right = 0
			utility_instance.offset_bottom = 0
		
		utility_background = utility_instance if utility_instance is UtilityBackground else null

func return_ingredients_to_bag():
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == slot_id:
				for bag_slot_id in range(BAG_MIN, BAG_MAX + 1):
					var slot_occupied = false
					for check_item in GameInfo.current_player.bag_slots:
						if check_item.bag_slot_id == bag_slot_id:
							slot_occupied = true
							break
					
					if not slot_occupied:
						item.bag_slot_id = bag_slot_id
						break
				break
	
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	for container in slot_containers:
		container.clear_slot()
	
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
	if GameInfo.current_player.silver < BREW_COST:
		return
	
	var items_to_brew = []
	var original_slots = []
	
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			items_to_brew.append(item)
			original_slots.append(original_bag_slots.get(slot_id, -1))
	
	if items_to_brew.is_empty():
		return
	
	# Send WebSocket with original bag slot IDs (10-14)
	if original_slots.size() == 1:
		Websocket.brew_elixir(original_slots[0])
	elif original_slots.size() == 2:
		Websocket.brew_elixir(original_slots[0], original_slots[1])
	else:
		Websocket.brew_elixir(original_slots[0], original_slots[1], original_slots[2])
	
	# Client-side simulation
	UIManager.instance.update_silver(-BREW_COST)
	
	var ingredient_ids = []
	for item in items_to_brew:
		ingredient_ids.append(item.id)
	
	var new_elixir = GameInfo.Item.new({
		"id": 1000,
		"bag_slot_id": find_empty_bag_slot(),
		"ingredients": ingredient_ids
	})
	GameInfo.current_player.bag_slots.append(new_elixir)
	
	for item in items_to_brew:
		GameInfo.current_player.bag_slots.erase(item)
	
	# Clear tracking
	original_bag_slots.clear()
	
	clear_ingredient_slots()
	utility_background.show_action_greeting()
	UIManager.instance.refresh_bags()
	utility_background.show_action_greeting()
	UIManager.instance.refresh_bags()

func clear_ingredient_slots():
	var slot_containers = [ingredient_slot1, ingredient_slot2, ingredient_slot3]
	for container in slot_containers:
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
