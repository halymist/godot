extends Panel

# EnchanterPanel-specific functionality

# Slot numbering constants
const ENCHANTER_SLOT = 15
const BAG_MIN = 10
const BAG_MAX = 14

@export var utility_background_container: Control
@export var bag: Control
@export var enchanter_slot: Control
@export var enchant_button: Button
@export var effect_list: VBoxContainer
@export var enchant_option_scene: PackedScene

const ENCHANT_COST = 10

var utility_background: UtilityBackground
var selected_effect_id: int = 0
var selected_effect_factor: float = 0.0
var working_item: GameInfo.Item = null  # Reference to item being worked on (doesn't change bag_slot_id)

func _ready():
	visibility_changed.connect(_on_visibility_changed)
	enchant_button.pressed.connect(_on_enchant_pressed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	update_enchant_button_state()
	populate_effect_list()

func on_item_placed(item: GameInfo.Item, _source_slot_id: int):
	"""Called when an item is placed in the enchanter slot (item keeps its original bag_slot_id)"""
	print("DEBUG EnchanterPanel.on_item_placed: item=", item.item_name, " bag_slot_id=", item.bag_slot_id)
	working_item = item
	utility_background.show_item_placed_greeting()
	update_enchant_button_state()
	populate_effect_list()

func on_item_removed():
	"""Called when an item is removed from the enchanter slot"""
	print("DEBUG EnchanterPanel.on_item_removed")
	working_item = null
	update_enchant_button_state()
	populate_effect_list()

func get_working_item() -> GameInfo.Item:
	"""Return the item currently being worked on (for excluding from bag refresh)"""
	return working_item

func on_slot_changed(slot_id: int):
	"""Legacy - Called by UIManager when a utility slot changes (for compatibility)"""
	print("DEBUG EnchanterPanel.on_slot_changed called with slot_id=", slot_id)
	# This is now handled by on_item_placed/on_item_removed
	pass

func _on_visibility_changed():
	if not visible:
		return_enchanter_item_to_bag()
	else:
		update_enchant_button_state()
		populate_effect_list()
		utility_background.show_entered_greeting()

func _load_location_content():
	var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location)
	
	for child in utility_background_container.get_children():
		child.queue_free()
	
	var utility_instance = location_data.enchanter_utility_scene.instantiate()
	utility_background_container.add_child(utility_instance)
	
	utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	utility_instance.offset_left = 0
	utility_instance.offset_top = 0
	utility_instance.offset_right = 0
	utility_instance.offset_bottom = 0
	
	utility_background = utility_instance


func return_enchanter_item_to_bag():
	# Just clear the visual slot and reset working_item
	# The item never actually moved - it keeps its original bag_slot_id
	if working_item:
		print("DEBUG return_enchanter_item_to_bag: clearing working_item")
		working_item = null
		if enchanter_slot.has_method("clear_slot"):
			enchanter_slot.clear_slot()
		UIManager.instance.refresh_bags()

func update_enchant_button_state():
	var has_item = working_item != null
	var has_silver = GameInfo.current_player.silver >= ENCHANT_COST
	var has_selection = selected_effect_id > 0
	enchant_button.disabled = not (has_item and has_silver and has_selection)

func populate_effect_list():
	for child in effect_list.get_children():
		child.queue_free()
	
	selected_effect_id = 0
	selected_effect_factor = 0.0
	
	var item_type = ""
	if working_item:
		item_type = working_item.type
	
	# Only show effects that the player has unlocked (from enchanter_effects array)
	var available_effect_ids = GameInfo.current_player.enchanter_effects
	
	for effect_id in available_effect_ids:
		var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
		if not effect or effect.factor == 0:
			continue
		
		var effect_slot = effect.get_slot_string()
		if working_item and effect_slot != "" and effect_slot != item_type:
			continue
		
		var option = enchant_option_scene.instantiate()
		option.setup(effect)
		option.pressed.connect(_on_effect_selected.bind(effect.id, effect.factor, option))
		effect_list.add_child(option)
	
	update_enchant_button_state()

func _on_effect_selected(effect_id: int, factor: float, option):
	selected_effect_id = effect_id
	selected_effect_factor = factor
	
	for child in effect_list.get_children():
		if child.has_method("set_selected"):
			child.set_selected(child == option)
	
	update_enchant_button_state()

func _on_enchant_pressed():
	if not working_item or selected_effect_id == 0:
		print("No working item or no effect selected")
		return
	
	# Send enchant request to server with the item's actual bag_slot_id
	print("DEBUG: Sending enchant_item for slot ", working_item.bag_slot_id, " with effect ", selected_effect_id)
	Websocket.enchant_item(working_item.bag_slot_id, selected_effect_id)
	
	# Apply enchant instantly on client (rollback later if server rejects)
	working_item.effect_overdrive = selected_effect_id
	UIManager.instance.update_silver(-ENCHANT_COST)
	
	utility_background.show_action_greeting()
	
	# Clear the slot and return item to bag visually
	if enchanter_slot.has_method("clear_slot"):
		enchanter_slot.clear_slot()
	working_item = null
	selected_effect_id = 0
	selected_effect_factor = 0.0
	populate_effect_list()
	update_enchant_button_state()
	UIManager.instance.refresh_bags()
	UIManager.instance.refresh_stats()

func hide_panel():
	"""Explicitly hide panel and clean up"""
	return_enchanter_item_to_bag()
	visible = false
