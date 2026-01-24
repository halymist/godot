extends Control
@export var inventory_slots: Array[Control]
@export var item_prefab: PackedScene
@export var is_bag: bool = false

func _ready():
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	update_equip_slots()


func update_equip_slots():
	if not GameInfo.current_player:
		return
		
	# Clear only the ItemContainer, preserve backgrounds and outlines
	for slot in inventory_slots:
		if slot.has_method("clear_slot"):
			slot.clear_slot()

	# Get items currently in utility slots (to exclude from bag display)
	var items_in_utility: Array[GameInfo.Item] = []
	if UIManager.instance:
		items_in_utility = UIManager.instance.get_items_in_utility_slots()

	# Slot numbering: Equipment 1-9, Consume 29, Bag 10-14, Special 15+
	for item in GameInfo.current_player.bag_slots:
		# Skip items currently placed in utility slots
		if item in items_in_utility:
			continue
		var bag_slot_id = item.bag_slot_id
		
		var valid = false
		var slot_id = 0
		
		if is_bag:
			# Bag slots: 10-14 → display as indices 0-4
			if bag_slot_id >= 10 and bag_slot_id <= 14:
				slot_id = bag_slot_id - 10
				valid = true
		else:
			# Equipment slots: 1-9 → display as indices 0-8
			if bag_slot_id >= 1 and bag_slot_id <= 9:
				slot_id = bag_slot_id - 1
				valid = true

		if valid and slot_id < inventory_slots.size():
			var icon = item_prefab.instantiate()
			icon.set_item_data(item)
			inventory_slots[slot_id].add_child(icon)
	
	for slot in inventory_slots:
		slot.update_slot_appearance()
