# SlotContainer.gd - Attach to your AspectRatioContainer (the slot itself)
extends Control

@export var item_scene: PackedScene 
@onready var slot_background = get_parent().get_node("Background")
@onready var item_outline = get_parent().get_node("Outline")

@export var slot_type: String = "Bag" # "Head", "Weapon", "Bag", etc.
@export var slot_id: int

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
	var item = data["item"]
	var source_container = data["source_container"]
	
	# Update GameInfo directly based on the operation
	if not is_slot_empty():
		# Swapping items
		var existing_item_data = get_item_data()
		
		# Update slot IDs for both items
		item.bag_slot_id = slot_id
		if existing_item_data:
			existing_item_data.bag_slot_id = source_container.slot_id if source_container else -1
		
		# Update GameInfo - find and update both items
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.id == item.id:
				game_item.bag_slot_id = slot_id
			elif existing_item_data and game_item.id == existing_item_data.id:
				game_item.bag_slot_id = source_container.slot_id if source_container else -1

		place_item_in_slot(item)
		if source_container:
			source_container.place_item_in_slot(existing_item_data)
	else:
		# Moving to empty slot
		item.bag_slot_id = slot_id
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.id == item.id:
				game_item.bag_slot_id = slot_id
				break
				
		place_item_in_slot(item)
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
