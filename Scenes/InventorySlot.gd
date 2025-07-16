# SlotContainer.gd - Attach to your AspectRatioContainer (the slot itself)
extends AspectRatioContainer

@export var item_scene: PackedScene 

@onready var slot_background = $Background
@onready var item_outline = $Outline  
@onready var item_container = $ItemContainer

@export var slot_type: String = "Bag"  # "Head", "Weapon", "Bag", etc.

func _ready():
    update_slot_appearance()

func _can_drop_data(_pos, data):
    # Check if item type matches slot type
    if not (data is Dictionary and data.has("item_name")):
        return false
    
    var item_type = data.get("type", "")
    return is_valid_item_for_slot(item_type) and is_slot_empty()

func _drop_data(_pos, data):
    # Handle the drop at slot level
    place_item_in_slot(data)
    
    # Clear the source item if it exists
    if data.has("_source_item"):
        var source_item = data["_source_item"]
        if source_item and source_item.has_method("clear_slot"):
            source_item.clear_slot()
            
    # Remove the temporary reference
    data.erase("_source_item")

func is_valid_item_for_slot(item_type: String) -> bool:
    match slot_type:
        "Head":
            return item_type == "Head"
        "Weapon":
            return item_type == "Weapon"
        "Bag":
            return true  # Bag accepts everything
        _:
            return false

func is_slot_empty() -> bool:
    return item_container.get_child_count() == 0

func place_item_in_slot(item_data: Dictionary):
    # Clear existing item
    clear_slot()
    
    # Create new item
    var new_item = item_scene.instantiate()
    new_item.set_item_data(item_data)
    item_container.add_child(new_item)
    
    update_slot_appearance()
    print("Placed ", item_data.get("item_name", "Unknown"), " in ", slot_type, " slot")

func clear_slot():
    for child in item_container.get_children():
        child.queue_free()
    update_slot_appearance()

func update_slot_appearance():
    var is_empty = is_slot_empty()
    print("Updating slot appearance - isEmpty: ", is_empty, " childCount: ", item_container.get_child_count())
    
    if item_outline:
        item_outline.visible = is_empty
        print("Outline visibility set to: ", is_empty)
    

func get_item_data() -> Dictionary:
    if not is_slot_empty():
        var item = item_container.get_child(0)
        if item.has_method("get_item_data"):
            return item.get_item_data()
    return {}