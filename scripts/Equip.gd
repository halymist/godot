extends Control
@export var inventory_slots: Array[Control]
@export var item_prefab: PackedScene
@export var is_bag: bool = false

func _ready():
	update_equip_slots()
	# Connect to bag slots changed signal to update when items move


func update_equip_slots():
	# Clear only the ItemContainer, preserve backgrounds and outlines
	for slot in inventory_slots:
		if slot.has_method("clear_slot"):
			slot.clear_slot()

	# Slot numbering: Equipment 0-8, Consume 9, Bag 10-14, Special 15+
	for item in GameInfo.current_player.bag_slots:
		var bag_slot_id = item.bag_slot_id
		
		var valid = false
		var slot_id = 0
		
		if is_bag:
			# Bag slots: 10-14 → display as indices 0-4
			if bag_slot_id >= 10 and bag_slot_id <= 14:
				slot_id = bag_slot_id - 10
				valid = true
		else:
			# Equipment slots: 0-8 → display as indices 0-8
			if bag_slot_id >= 0 and bag_slot_id <= 8:
				slot_id = bag_slot_id
				valid = true

		if valid and slot_id < inventory_slots.size():
			var icon = item_prefab.instantiate()
			icon.set_item_data(item)
			inventory_slots[slot_id].add_child(icon)
	
	for slot in inventory_slots:
		slot.update_slot_appearance()
