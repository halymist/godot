# SlotContainer.gd - Attach to your AspectRatioContainer (the slot itself)
extends Control

@export var item_scene: PackedScene 
@onready var slot_background = get_parent().get_node("Background")
@onready var item_outline = get_parent().get_node("Outline")

@export var slot_type: String = "Bag" # "Head", "Weapon", "Bag", etc.
@export var slot_id: int

func _ready():
	# Override cursor to always be arrow (no forbidden cursor during drag)
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func _can_drop_data(_pos, data):
	# Check if data is valid drag package
	if not (data is Dictionary and data.has("item") and data["item"] is GameInfo.Item):
		return false
	
	var item = data["item"]
	var item_type = item.type
	
	# Check if dragged item can go into this slot
	if not is_valid_item_for_slot(item_type):
		return false
	
	# If slot is empty, we're good
	if is_slot_empty():
		return true
	
	# If slot has an item, check if that item can go back to source
	var existing_item_data = get_item_data()
	if not existing_item_data:
		return true
		
	var existing_item_type = existing_item_data.type
	var source_container = data["source_container"]
	
	# Check if the existing item can go back to the source slot
	if source_container and source_container.has_method("is_valid_item_for_slot"):
		# Check if source slot can accept the existing item
		return source_container.is_valid_item_for_slot(existing_item_type)
	
	# If we can't validate the reverse swap, don't allow it
	return false

func _drop_data(_pos, data):
	# Extract item and source container from drag package
	var dragged_item = data["item"]
	var source_container = data["source_container"]
	var source_slot_id = source_container.slot_id if source_container else -1
	
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
		"Bag":
			return true  # Bag accepts everything
		_:
			return false

func is_slot_empty() -> bool:
	var count = get_child_count()
	return count == 0

func place_item_in_slot(item_data: GameInfo.Item):
	if not is_slot_empty():
		clear_slot()
	
	# Create new item
	var new_item = item_scene.instantiate()
	new_item.set_item_data(item_data)
	add_child(new_item)
	
	update_slot_appearance()
func clear_slot():
	for child in get_children():
		child.free()
	update_slot_appearance()

func update_slot_appearance():
	var is_empty = is_slot_empty()
	if item_outline:
		item_outline.visible = is_empty

func get_item_data() -> GameInfo.Item:
	if not is_slot_empty():
		var item = get_child(0)
		if item.has_method("get_item_data"):
			return item.get_item_data()
	return null
