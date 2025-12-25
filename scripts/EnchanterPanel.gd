extends Panel

# EnchanterPanel-specific functionality

@export var background_rect: TextureRect
@export var description_label: Label
@export var bag: Control
@export var enchanter_slot: Control
@export var enchant_button: Button
@export var effect_list: VBoxContainer

const ENCHANT_COST = 10

var selected_effect_id: int = 0
var selected_effect_factor: float = 0.0

func _ready():
	_load_location_content()
	# Connect to visibility changes to handle cleanup
	visibility_changed.connect(_on_visibility_changed)
	# Connect to slot changes for enchanter slot (104)
	UIManager.instance.utility_slot_changed.connect(_on_utility_slot_changed)
	if enchant_button:
		enchant_button.pressed.connect(_on_enchant_pressed)
	update_enchant_button_state()
	populate_effect_list()
	# Connect to layout mode changes
	UIManager.instance.resolution_manager.layout_mode_changed.connect(_on_layout_mode_changed)

func _on_layout_mode_changed(is_wide: bool):
	if bag:
		bag.visible = not is_wide

func _on_utility_slot_changed(slot_id: int):
	if slot_id == 104:  # Enchanter slot
		update_enchant_button_state()
		populate_effect_list()

func _on_visibility_changed():
	# When panel is hidden, return item from enchanter slot to bag
	if not visible:
		return_enchanter_item_to_bag()
	else:
		update_enchant_button_state()
		populate_effect_list()

func _load_location_content():
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	background_rect.texture = location_data.enchanter_background
	description_label.text = location_data.get_random_enchanter_greeting()


func return_enchanter_item_to_bag():
	# Find any item in slot 104 (enchanter slot) and return it to first available bag slot
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 104:
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
					# Clear the enchanter slot visually
					if enchanter_slot and enchanter_slot.has_method("clear_slot"):
						enchanter_slot.clear_slot()
					UIManager.instance.refresh_bags()
					return

func update_enchant_button_state():
	if not enchant_button:
		return
	
	# Check if there's an item in the enchanter slot
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 104:
			item_in_slot = item
			break
	
	# Button is enabled only if there's an item, player has enough gold, and an effect is selected
	var has_item = item_in_slot != null
	var has_silver = GameInfo.current_player.silver >= ENCHANT_COST
	var has_selection = selected_effect_id > 0
	enchant_button.disabled = not (has_item and has_silver and has_selection)

func populate_effect_list():
	if not effect_list:
		return
	
	# Clear existing effects
	for child in effect_list.get_children():
		child.queue_free()
	
	selected_effect_id = 0
	selected_effect_factor = 0.0
	
	# Get item in slot to filter by type
	var item_in_slot = null
	var item_type = ""
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 104:
			item_in_slot = item
			item_type = item.type
			break
	
	# Populate effect list from effects_db (client-side data)
	if not GameInfo.effects_db:
		return
	
	for effect in GameInfo.effects_db.effects:
		if effect.factor == 0:  # Skip effects without enchanting factor
			continue
		
		# Filter by item type if an item is in the slot
		if item_in_slot and effect.slot != "" and effect.slot != item_type:
			continue
		
		# Create effect button with description
		var button = Button.new()
		button.text = "%s %s%%" % [effect.description, str(effect.factor)]
		button.custom_minimum_size = Vector2(0, 30)
		button.theme_type_variation = "FlatButton"
		
		# Style the button
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.5, 0.5, 0.6, 1)
		button.add_theme_stylebox_override("normal", normal_style)
		
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.3, 0.3, 0.35, 0.9)
		hover_style.border_width_left = 2
		hover_style.border_width_right = 2
		hover_style.border_width_top = 2
		hover_style.border_width_bottom = 2
		hover_style.border_color = Color(0.7, 0.7, 0.8, 1)
		button.add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style = StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.4, 0.6, 0.8, 0.9)
		pressed_style.border_width_left = 2
		pressed_style.border_width_right = 2
		pressed_style.border_width_top = 2
		pressed_style.border_width_bottom = 2
		pressed_style.border_color = Color(0.6, 0.8, 1.0, 1)
		button.add_theme_stylebox_override("pressed", pressed_style)
		
		button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
		button.add_theme_font_size_override("font_size", 12)
		
		# Connect button press
		button.pressed.connect(_on_effect_selected.bind(effect.id, effect.factor, button))
		
		effect_list.add_child(button)
	
	update_enchant_button_state()

func _on_effect_selected(effect_id: int, factor: float, button: Button):
	# Update selection
	selected_effect_id = effect_id
	selected_effect_factor = factor
	
	# Update visual state of all buttons
	for child in effect_list.get_children():
		if child is Button:
			if child == button:
				# Selected state
				var selected_style = StyleBoxFlat.new()
				selected_style.bg_color = Color(0.4, 0.6, 0.8, 0.9)
				selected_style.border_width_left = 2
				selected_style.border_width_right = 2
				selected_style.border_width_top = 2
				selected_style.border_width_bottom = 2
				selected_style.border_color = Color(0.6, 0.8, 1.0, 1)
				child.add_theme_stylebox_override("normal", selected_style)
			else:
				# Normal state
				var normal_style = StyleBoxFlat.new()
				normal_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
				normal_style.border_width_left = 2
				normal_style.border_width_right = 2
				normal_style.border_width_top = 2
				normal_style.border_width_bottom = 2
				normal_style.border_color = Color(0.5, 0.5, 0.6, 1)
				child.add_theme_stylebox_override("normal", normal_style)
	
	update_enchant_button_state()

func _on_enchant_pressed():
	# Find item in slot 104
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 104:
			item_in_slot = item
			break
	
	if not item_in_slot or selected_effect_id == 0:
		return
	
	# Deduct silver
	UIManager.instance.update_silver(-ENCHANT_COST)
	
	# Apply enchantment
	if item_in_slot.effect_id > 0:
		# Item already has an effect - apply to overdrive
		item_in_slot.enchant_overdrive = selected_effect_id
		print("Applied enchantment to overdrive: ", selected_effect_id, " with factor ", selected_effect_factor)
	else:
		# Item has no effect - apply as main effect
		item_in_slot.effect_id = selected_effect_id
		item_in_slot.effect_factor = selected_effect_factor
		
		# Look up effect details
		if GameInfo.effects_db:
			var effect = GameInfo.effects_db.get_effect_by_id(selected_effect_id)
			if effect:
				item_in_slot.effect_name = effect.name
				item_in_slot.effect_description = effect.description
		
		print("Applied enchantment as main effect: ", selected_effect_id, " with factor ", selected_effect_factor)
	
	# Move item back to bag (like tempering)
	return_enchanter_item_to_bag()
	
	# Reset selection
	selected_effect_id = 0
	selected_effect_factor = 0.0
	populate_effect_list()
	update_enchant_button_state()

func hide_panel():
	"""Explicitly hide panel and clean up"""
	return_enchanter_item_to_bag()
	visible = false
