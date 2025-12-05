@tool
extends "res://scripts/UtilityPanel.gd"

# VendorPanel-specific functionality

@onready var vendor_slots: Array[Control] = []

func _ready():
	super._ready()
	
	if Engine.is_editor_hint():
		return
	
	# Get vendor slot references (slots 105-112 for 8 items)
	var vendor_grid = $ItemsPanel/VendorSlots
	if vendor_grid:
		for i in range(1, 9):  # Vendor1 through Vendor8
			var vendor_slot = vendor_grid.get_node_or_null("Vendor%d/ItemContainer" % i)
			if vendor_slot:
				vendor_slots.append(vendor_slot)
	
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

