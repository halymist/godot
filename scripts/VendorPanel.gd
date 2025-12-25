extends Panel

@export var background_rect: TextureRect
@export var description_label: Label
@export var bag: Control
@export var vendor_grid: GridContainer
@onready var vendor_slots: Array[Control] = []

func _ready():
	UIManager.instance.resolution_manager.layout_mode_changed.connect(_on_layout_mode_changed)
	_load_location_content()
	# Get vendor slot references (slots 105-112 for 8 items)
	if vendor_grid:
		for i in range(1, 9):  # Vendor1 through Vendor8
			var vendor_slot = vendor_grid.get_node_or_null("Vendor%d" % i)
			if vendor_slot:
				vendor_slots.append(vendor_slot)
	
	populate_vendor_slots()

func _on_layout_mode_changed(is_wide: bool):
	if bag:
		bag.visible = not is_wide

func _load_location_content():
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	if background_rect and location_data.vendor_background:
		background_rect.texture = location_data.vendor_background
	if description_label:
		description_label.text = location_data.get_random_vendor_greeting()
		background_rect.texture = location_data.vendor_background

func _on_bag_slots_changed():
	# Refresh vendor slots when bag changes (items bought/sold)
	if visible:
		populate_vendor_slots()

func populate_vendor_slots():
	# Clear all vendor slots first
	for slot in vendor_slots:
		if slot.has_method("clear_slot"):
			slot.clear_slot()
	
	# Populate vendor slots with vendor_items from GameInfo (order doesn't matter)
	for i in range(min(GameInfo.vendor_items.size(), vendor_slots.size())):
		var item = GameInfo.vendor_items[i]
		var slot = vendor_slots[i]
		# Set bag_slot_id to vendor slot ID (105-112) for pricing
		item.bag_slot_id = 105 + i
		
		# Get item scene and instantiate
		var item_scene = load("res://Scenes/item.tscn")
		if item_scene:
			var icon = item_scene.instantiate()
			icon.set_item_data(item)
			slot.add_child(icon)
	
	# Update visual appearance for all slots
	for slot in vendor_slots:
		if slot.has_method("update_slot_appearance"):
			slot.update_slot_appearance()
