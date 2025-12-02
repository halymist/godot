extends HBoxContainer
@export var inventory_slots: Array[Control]
@export var item_prefab: PackedScene
@export var is_bag: bool = false

func _ready():
	update_equip_slots()
	# Connect visibility changed for bags to refresh when shown
	if is_bag:
		visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	# Refresh bag contents when it becomes visible
	if visible:
		update_equip_slots()

func update_equip_slots():
	# Clear only the ItemContainer, preserve backgrounds and outlines
	for slot in inventory_slots:
		if slot.has_method("clear_slot"):
			slot.clear_slot()

	#eq slotsID: 0-9, bagslots: 10-14
	for item in GameInfo.current_player.bag_slots:
		var bag_slot_id = item.bag_slot_id  # Use property instead of dictionary access
		var valid = false
		var slot_id = 0
		if is_bag and bag_slot_id >= 10:
			slot_id = bag_slot_id - 10
			valid = true
		elif not is_bag and bag_slot_id < 10:
			slot_id = bag_slot_id
			valid = true

		if valid:
			var icon = item_prefab.instantiate()
			icon.set_item_data(item)
			inventory_slots[slot_id].add_child(icon)
	
	for slot in inventory_slots:
		slot.update_slot_appearance()
