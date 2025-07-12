extends HBoxContainer
@export var inventory_slots: Array[TextureRect]
@export var item_prefab: PackedScene
@export var is_bag: bool = false

func _ready():
	update_equip_slots()

func update_equip_slots():
	# Clear all slots
	for slot in inventory_slots:
		for child in slot.get_children():
			child.queue_free()

	#eq slotsID: 0-9, bagslots: 10-14
	for item in GameInfo.current_player.bag_slots:
		var bag_slot_id = int(item["bag_slot_id"])
		var valid = false
		var slot_id = 0
		if is_bag and bag_slot_id >= 10:
			slot_id = bag_slot_id - 10
			valid = true
		elif not is_bag and bag_slot_id < 10:
			slot_id = bag_slot_id
			valid = true

		if valid:
			var tex = item.get("texture", null)
			if tex:
				var icon = item_prefab.instantiate()
				icon.texture = tex
				inventory_slots[slot_id].add_child(icon)
