extends Panel

# Slot numbering constants
const VENDOR_MIN = 21
const VENDOR_MAX = 28

@export var utility_background_container: Control
@export var bag: Control
@export var vendor_grid: GridContainer
@onready var vendor_slots: Array[Control] = []

var utility_background: UtilityBackground  # Found from loaded utility scene

func _ready():
	# Don't load location content yet - wait for character selection
	# Get vendor slot references (slots 21-28 for 8 items)
	if vendor_grid:
		for i in range(1, 9):  # Vendor1 through Vendor8
			var vendor_slot = vendor_grid.get_node_or_null("Vendor%d" % i)
			if vendor_slot:
				vendor_slots.append(vendor_slot)
	
	# Connect to character changed signal
	GameInfo.character_changed.connect(_on_character_changed)
	
	# Connect visibility signal for chat greeting
	visibility_changed.connect(_on_visibility_changed)

func _on_character_changed():
	_load_location_content()
	populate_vendor_slots()

func _on_visibility_changed():
	if visible:
		populate_vendor_slots()
		# Show entered greeting when panel becomes visible
		if utility_background:
			utility_background.show_entered_greeting()

func _load_location_content():
	if not GameInfo.current_player:
		return
		
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	
	# Clear existing children from container
	if utility_background_container:
		for child in utility_background_container.get_children():
			child.queue_free()
	
	# Instantiate and add the utility scene
	if location_data.vendor_utility_scene:
		var utility_instance = location_data.vendor_utility_scene.instantiate()
		utility_background_container.add_child(utility_instance)
		
		# Set to full rect (anchors 0,0 to 1,1 with zero offsets)
		if utility_instance is Control:
			utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
			utility_instance.offset_left = 0
			utility_instance.offset_top = 0
			utility_instance.offset_right = 0
			utility_instance.offset_bottom = 0
		
		# Get reference to the utility background script
		if utility_instance is UtilityBackground:
			utility_background = utility_instance
		else:
			utility_background = null

func trigger_purchase_greeting():
	"""Called by InventorySlot when player purchases from vendor"""
	if utility_background:
		utility_background.show_action_greeting()

func trigger_sell_greeting():
	"""Called by InventorySlot when player sells to vendor"""
	if utility_background:
		utility_background.show_item_placed_greeting()

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
		# Set bag_slot_id to vendor slot ID (21-28) for pricing
		item.bag_slot_id = VENDOR_MIN + i
		
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
