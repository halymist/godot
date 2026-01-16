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
var original_bag_slot: int = -1

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

func on_slot_changed(slot_id: int):
	if slot_id == ENCHANTER_SLOT:
		var item_in_slot = null
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == ENCHANTER_SLOT:
				item_in_slot = item
				break
		if item_in_slot:
			# Track the bag slot this item came from (before moving to ENCHANTER_SLOT)
			# Note: This should be set by ItemSlot when moving the item
			for slot_id_check in range(BAG_MIN, BAG_MAX + 1):
				var found_empty = true
				for check_item in GameInfo.current_player.bag_slots:
					if check_item != item_in_slot and check_item.bag_slot_id == slot_id_check:
						found_empty = false
						break
				if found_empty:
					original_bag_slot = slot_id_check
					break
			utility_background.show_item_placed_greeting()
		update_enchant_button_state()
		populate_effect_list()

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
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == ENCHANTER_SLOT:
			for slot_id in range(BAG_MIN, BAG_MAX + 1):
				var slot_occupied = false
				for check_item in GameInfo.current_player.bag_slots:
					if check_item.bag_slot_id == slot_id:
						slot_occupied = true
						break
				
				if not slot_occupied:
					item.bag_slot_id = slot_id
					if enchanter_slot.has_method("clear_slot"):
						enchanter_slot.clear_slot()
					UIManager.instance.refresh_bags()
					return

func update_enchant_button_state():
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == ENCHANTER_SLOT:
			item_in_slot = item
			break
	
	var has_item = item_in_slot != null
	var has_silver = GameInfo.current_player.silver >= ENCHANT_COST
	var has_selection = selected_effect_id > 0
	enchant_button.disabled = not (has_item and has_silver and has_selection)

func populate_effect_list():
	for child in effect_list.get_children():
		child.queue_free()
	
	selected_effect_id = 0
	selected_effect_factor = 0.0
	
	var item_in_slot = null
	var item_type = ""
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == ENCHANTER_SLOT:
			item_in_slot = item
			item_type = item.type
			break
	
	for effect in GameInfo.effects_db.effects:
		if effect.factor == 0:
			continue
		
		var effect_slot = effect.get_slot_string()
		if item_in_slot and effect_slot != "" and effect_slot != item_type:
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
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == ENCHANTER_SLOT:
			item_in_slot = item
			break
	
	if not item_in_slot or selected_effect_id == 0:
		return
	
	Websocket.enchant_item(original_bag_slot, selected_effect_id)
	
	UIManager.instance.update_silver(-ENCHANT_COST)
	
	item_in_slot.effect_overdrive = selected_effect_id
	print("Applied enchantment overdrive: ", selected_effect_id)
	
	utility_background.show_action_greeting()
	
	return_enchanter_item_to_bag()
	
	selected_effect_id = 0
	selected_effect_factor = 0.0
	populate_effect_list()
	update_enchant_button_state()

func hide_panel():
	"""Explicitly hide panel and clean up"""
	return_enchanter_item_to_bag()
	visible = false
