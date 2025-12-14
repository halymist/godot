# SlotContainer.gd - Attach to the slot Control (root level)
extends Control

@export var item_scene: PackedScene
@export var outline_texture: Texture2D  # Outline texture for equipment slots (bag slots leave empty)
@onready var slot_background = get_node_or_null("Background")
@onready var item_outline = get_node_or_null("Outline")

@export var slot_type: String = "Bag" # "Head", "Weapon", "Bag", etc.
@export var slot_id: int

func _ready():
	# Override cursor to always be arrow (no forbidden cursor during drag)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	# Set outline texture if provided (equipment slots only)
	if outline_texture and item_outline:
		item_outline.texture = outline_texture
	
	# Update slot appearance to show outline if empty
	update_slot_appearance()

func _can_drop_data(_pos, data):
	# Check if data is valid drag package
	if not (data is Dictionary and data.has("item") and data["item"] is GameInfo.Item):
		return false
	
	var item = data["item"]
	var item_type = item.type
	var source_container = data.get("source_container")
	var source_slot_id = source_container.slot_id if source_container else -1
	
	print("DEBUG _can_drop_data: Target slot_id=", slot_id, " slot_type=", slot_type, " | Source slot_id=", source_slot_id, " | Dragged item type=", item_type)
	
	# Vendor slots (105-112) cannot accept drops - they're for purchasing only
	if slot_id >= 105 and slot_id <= 112:
		return false
	
	# Cannot drag between vendor slots
	if source_slot_id >= 105 and source_slot_id <= 112 and slot_id >= 105 and slot_id <= 112:
		return false
	
	# Check if dragged item can go into this slot
	if not is_valid_item_for_slot(item_type):
		return false
	
	# If slot is empty, we're good
	if is_slot_empty():
		print("DEBUG: Target slot is empty, allowing drop")
		return true
	
	# If slot has an item, check if that item can go back to source
	var existing_item_data = get_item_data()
	print("DEBUG: Target slot has item, existing_item_data = ", existing_item_data)
	if not existing_item_data:
		print("DEBUG: No existing item data found, allowing drop")
		return true
		
	var existing_item_type = existing_item_data.type
	print("DEBUG: Existing item type = ", existing_item_type)
	
	# Special case: Don't allow swapping equipment items of different types
	# Equipment slots are 0-8, and each has a specific type requirement
	if slot_id >= 0 and slot_id <= 8 and source_slot_id >= 0 and source_slot_id <= 8:
		# Both are equipment slots - only allow swap if same type
		if item_type != existing_item_type:
			return false
	
	# Also check when swapping between equipment and bag
	# If source is equipment (0-8) and target has an item, types must match
	if source_slot_id >= 0 and source_slot_id <= 8:
		# Source is equipment slot - the item types must match for a swap
		print("DEBUG: Equipment->bag swap check. Source slot: ", source_slot_id, " Target slot: ", slot_id)
		print("DEBUG: Dragged item type: ", item_type, " Existing item type: ", existing_item_type)
		
		# Get the required type for the source equipment slot
		var required_type = ""
		match source_slot_id:
			0: required_type = "Head"
			1: required_type = "Chest"
			2: required_type = "Hands"
			3: required_type = "Foot"
			4: required_type = "Belt"
			5: required_type = "Legs"
			6: required_type = "Ring"
			7: required_type = "Amulet"
			8: required_type = "Weapon"
		
		# Both items must match the equipment slot's required type
		if item_type != required_type or existing_item_type != required_type:
			print("DEBUG: REJECTING - Types don't match required type: ", required_type)
			return false
		print("DEBUG: ALLOWING - Both items match required type: ", required_type)
	
	# For all other swaps (bag to bag, utility slots, etc.), check if existing item can go to source
	if source_container and source_container.has_method("is_valid_item_for_slot"):
		return source_container.is_valid_item_for_slot(existing_item_type)
	
	# If we can't validate the reverse swap, don't allow it
	return false

func _drop_data(_pos, data):
	# Extract item and source container from drag package
	var dragged_item = data["item"]
	var source_container = data["source_container"]
	var source_slot_id = source_container.slot_id if source_container else -1
	
	# Special case: Purchasing from vendor (slots 105-112)
	if source_slot_id >= 105 and source_slot_id <= 112:
		handle_vendor_purchase(dragged_item, source_slot_id)
		return
	
	# Special case: Selling to vendor (slot 113)
	if slot_id == 113:
		handle_vendor_sell(dragged_item, source_slot_id, source_container)
		return
	
	# Update GameInfo directly based on the operation
	if not is_slot_empty():
		# Swapping items
		var existing_item = get_item_data()
		
		# Find the actual item instances in GameInfo.bag_slots by their current bag_slot_id
		# This is more reliable than matching by id (which can have duplicates)
		var dragged_item_in_array = null
		var existing_item_in_array = null
		
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.bag_slot_id == source_slot_id and dragged_item_in_array == null:
				# This is the item being dragged from source
				dragged_item_in_array = game_item
			elif game_item.bag_slot_id == slot_id and existing_item_in_array == null:
				# This is the item currently in this slot
				existing_item_in_array = game_item
		
		# Swap their bag_slot_ids
		if dragged_item_in_array:
			dragged_item_in_array.bag_slot_id = slot_id
		if existing_item_in_array:
			existing_item_in_array.bag_slot_id = source_slot_id

		place_item_in_slot(dragged_item)
		if source_container:
			source_container.place_item_in_slot(existing_item)
	else:
		# Moving to empty slot
		# Find the item by its current slot_id
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.bag_slot_id == source_slot_id:
				game_item.bag_slot_id = slot_id
				break
				
		place_item_in_slot(dragged_item)
		if source_container:
			source_container.clear_slot()

	print("Updated GameInfo: item moved to slot ", slot_id)
	GameInfo.bag_slots_changed.emit()

func handle_vendor_purchase(vendor_item: GameInfo.Item, _vendor_slot_id: int):
	# Vendor items cost 2x their base price
	var purchase_price = vendor_item.price * 2
	
	# Check if player has enough gold
	if GameInfo.current_player.gold < purchase_price:
		print("Not enough gold to purchase item! Need ", purchase_price, " but have ", GameInfo.current_player.gold)
		return
	
	# Check if target slot is empty
	if not is_slot_empty():
		print("Target slot must be empty to purchase item")
		return
	
	# Deduct gold
	GameInfo.current_player.gold -= purchase_price
	print("Purchased ", vendor_item.item_name, " for ", purchase_price, " gold. Remaining gold: ", GameInfo.current_player.gold)
	
	# Create a new item instance from vendor item (copy the data)
	var purchased_item = GameInfo.Item.new({
		"id": vendor_item.id,
		"bag_slot_id": slot_id
	})
	
	# Add to player's bag_slots
	GameInfo.current_player.bag_slots.append(purchased_item)
	
	# Remove item from vendor_items (don't replenish)
	var vendor_slot_index = _vendor_slot_id - 105  # Convert slot_id to index (105->0, 106->1, etc.)
	if vendor_slot_index >= 0 and vendor_slot_index < GameInfo.vendor_items.size():
		GameInfo.vendor_items.remove_at(vendor_slot_index)
		print("Removed item from vendor inventory at index ", vendor_slot_index)
	
	# Place in visual slot
	place_item_in_slot(purchased_item)
	
	# Emit signal to update UI
	GameInfo.bag_slots_changed.emit()
	print("Item purchased and added to slot ", slot_id)

func handle_vendor_sell(_item: GameInfo.Item, source_slot_id: int, source_container):
	# Only accept items from equipment (0-9) or bag (10-14) slots
	if source_slot_id < 0 or source_slot_id > 14:
		print("Can only sell items from equipment or bag slots")
		return
	
	# Find the item in bag_slots by its bag_slot_id
	var item_in_bag = null
	for game_item in GameInfo.current_player.bag_slots:
		if game_item.bag_slot_id == source_slot_id:
			item_in_bag = game_item
			break
	
	if not item_in_bag:
		print("Item not found in bag_slots")
		return
	
	# Add gold for selling the item
	GameInfo.current_player.gold += item_in_bag.price
	print("Sold ", item_in_bag.item_name, " for ", item_in_bag.price, " gold. Total gold: ", GameInfo.current_player.gold)
	
	# Remove item from bag_slots
	GameInfo.current_player.bag_slots.erase(item_in_bag)
	
	# Clear the source slot visually
	if source_container:
		source_container.clear_slot()
	
	# Emit signal to update UI
	GameInfo.bag_slots_changed.emit()
	print("Item sold and removed from inventory")

func is_valid_item_for_slot(item_type: String) -> bool:
	match slot_type:
		"Head":
			return item_type == "Head"
		"Chest":
			return item_type == "Chest"
		"Hands":
			return item_type == "Hands"
		"Foot":
			return item_type == "Foot"
		"Belt":
			return item_type == "Belt"		
		"Legs":
			return item_type == "Legs"
		"Ring":
			return item_type == "Ring"
		"Amulet":
			return item_type == "Amulet"
		"Weapon":
			return item_type == "Weapon"
		"Ingredient":
			return item_type == "Ingredient"
		"Blacksmith":
			return item_type != "Ingredient" and item_type != "Consumable"
		"Enchanter":
			return item_type != "Ingredient" and item_type != "Consumable" and item_type != "Elixir" and item_type != "Potion"
		"Bag":
			return true  # Bag accepts everything
		"Sell":
			return true  # Sell slot accepts everything from player inventory
		_:
			return false

func is_slot_empty() -> bool:
	# Check if slot has any children besides Background and Outline
	for child in get_children():
		if child != slot_background and child != item_outline:
			return false
	return true

func place_item_in_slot(item_data: GameInfo.Item):
	if not is_slot_empty():
		clear_slot()
	
	# Create new item
	var new_item = item_scene.instantiate()
	new_item.set_item_data(item_data)
	add_child(new_item)
	
	# Hide outline when item is placed
	if item_outline:
		item_outline.visible = false

func clear_slot():
	# Collect children to remove (except Background and Outline)
	var children_to_remove = []
	for child in get_children():
		if child != slot_background and child != item_outline:
			children_to_remove.append(child)
	
	# Free them with queue_free to avoid locked object errors
	for child in children_to_remove:
		child.queue_free()

func update_slot_appearance():
	# Count non-background/outline children that aren't queued for deletion
	var item_count = 0
	for child in get_children():
		if child != slot_background and child != item_outline and not child.is_queued_for_deletion():
			item_count += 1
	
	# Only show outline when empty AND outline_texture is set (equipment slots)
	if item_outline:
		item_outline.visible = (item_count == 0) and (outline_texture != null)

func get_item_data() -> GameInfo.Item:
	if not is_slot_empty():
		# Find the first child that is not background or outline
		for child in get_children():
			if child != slot_background and child != item_outline:
				if child.has_method("get_item_data"):
					return child.get_item_data()
	return null
