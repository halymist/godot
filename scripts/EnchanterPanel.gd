@tool
extends "res://scripts/UtilityPanel.gd"

# EnchanterPanel-specific functionality

@onready var enchanter_slot = $ItemsPanel/Content/ItemSlotContainer/ItemSlot/ItemContainer
@onready var enchant_button = $ItemsPanel/Content/EnchantButtonContainer/EnchantButton

const ENCHANT_COST = 10

func _ready():
	super._ready()
	# Connect to visibility changes to handle cleanup
	if not Engine.is_editor_hint():
		visibility_changed.connect(_on_visibility_changed)
		GameInfo.bag_slots_changed.connect(_on_item_changed)
		GameInfo.gold_changed.connect(_on_gold_changed)
		if enchant_button:
			enchant_button.pressed.connect(_on_enchant_pressed)
		update_enchant_button_state()

func _on_gold_changed(_new_gold):
	# Update button state when gold changes
	update_enchant_button_state()

func _on_visibility_changed():
	# When panel is hidden, return item from enchanter slot to bag
	if not visible:
		return_enchanter_item_to_bag()
	else:
		# When panel becomes visible, update button state
		update_enchant_button_state()

func _on_item_changed():
	# Update button state when item changes
	if visible:
		update_enchant_button_state()

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
					GameInfo.bag_slots_changed.emit()
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
	
	# Button is enabled only if there's an item and player has enough gold
	var has_item = item_in_slot != null
	var has_gold = GameInfo.current_player.gold >= ENCHANT_COST
	enchant_button.disabled = not (has_item and has_gold)

func _on_enchant_pressed():
	# Find item in slot 104
	var item_in_slot = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == 104:
			item_in_slot = item
			break
	
	if not item_in_slot:
		return
	
	# Check if player has enough gold
	if GameInfo.current_player.gold < ENCHANT_COST:
		return
	
	# Deduct gold
	GameInfo.current_player.gold -= ENCHANT_COST
	GameInfo.gold_changed.emit(GameInfo.current_player.gold)
	
	# TODO: Implement enchanting logic
	print("Enchanting item: ", item_in_slot.item_name)
	
	update_enchant_button_state()

func hide_panel():
	"""Explicitly hide panel and clean up"""
	return_enchanter_item_to_bag()
	visible = false
