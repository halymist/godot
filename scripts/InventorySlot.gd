# SlotContainer.gd - Attach to your AspectRatioContainer (the slot itself)
extends Control

@export var item_scene: PackedScene 
@onready var slot_background = get_parent().get_node("Background")
@onready var item_outline = get_parent().get_node("Outline")

@export var slot_type: String = "Bag" # "Head", "Weapon", "Bag", etc.
@export var slot_id: int

func _can_drop_data(_pos, data):
	# Check if data is valid
	if not (data is Dictionary and data.has("item_name")):
		return false
	
	var item_type = data.get("type", "")
	
	# Check if dragged item can go into this slot
	if not is_valid_item_for_slot(item_type):
		return false
	
	# If slot is empty, we're good
	if is_slot_empty():
		return true
	
	# If slot has an item, check if that item can go back to source
	var existing_item_data = get_item_data()
	var existing_item_type = existing_item_data.get("type", "")
	
	# Get source container and check if it can accept the existing item
	var source_item = data.get("_source_item")
	if source_item and is_instance_valid(source_item):
		var source_container = source_item.get_parent()
		if source_container and source_container.has_method("is_valid_item_for_slot"):
			# Check if source slot can accept the existing item
			return source_container.is_valid_item_for_slot(existing_item_type)
	
	# If we can't validate the reverse swap, don't allow it
	return false

func _drop_data(_pos, data):
	# Handle swapping if slot already has an item
	var source_item = data["_source_item"]
	var source_container = source_item.get_parent()
	
	# Update GameInfo directly based on the operation
	if not is_slot_empty():
		# Swapping items
		var existing_item_data = get_item_data()
		
		# Update slot IDs for both items
		data["bag_slot_id"] = slot_id
		existing_item_data["bag_slot_id"] = source_container.slot_id
		
		# Update GameInfo - find and update both items
		for item in GameInfo.current_player.bag_slots:
			if item.get("id") == data.get("id"):
				item["bag_slot_id"] = slot_id
			elif item.get("id") == existing_item_data.get("id"):
				item["bag_slot_id"] = source_container.slot_id

		place_item_in_slot(data)
		source_container.place_item_in_slot(existing_item_data)
	else:
		data["bag_slot_id"] = slot_id
		for item in GameInfo.current_player.bag_slots:
			if item.get("id") == data.get("id"):
				item["bag_slot_id"] = slot_id
				break
				
		place_item_in_slot(data)
		source_container.clear_slot()

	print("Updated GameInfo: item moved to slot ", slot_id)
	GameInfo.bag_slots_changed.emit()
	data.erase("_source_item")

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

func place_item_in_slot(item_data: Dictionary):
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

func get_item_data() -> Dictionary:
	if not is_slot_empty():
		var item = get_child(0)
		if item.has_method("get_item_data"):
			return item.get_item_data()
	return {}
