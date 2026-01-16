extends Panel

# Slot numbering constants
const VENDOR_MIN = 21
const VENDOR_MAX = 28

@export var utility_background_container: Control
@export var bag: Control
@export var vendor_grid: GridContainer
@onready var vendor_slots: Array[Control] = []

var utility_background: UtilityBackground  # Found from loaded utility scene
var vendor_items: Array[GameInfo.Item] = []  # Local vendor inventory

func _ready():
	# Don't load location content yet - wait for character selection
	# Get vendor slot references (slots 21-28 for 8 items)
	if vendor_grid:
		for i in range(1, 9):  # Vendor1 through Vendor8
			var vendor_slot = vendor_grid.get_node_or_null("Vendor%d" % i)
			if vendor_slot:
				vendor_slots.append(vendor_slot)
	
	# Initialize if character is already selected
	if GameInfo.current_player:
		_load_location_content()
		populate_vendor_slots()
	
	# Connect visibility signal for chat greeting
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		populate_vendor_slots()
		# Show entered greeting when panel becomes visible
		if utility_background:
			utility_background.show_entered_greeting()

func _load_location_content():
	if not GameInfo.current_player:
		return
	
	# Load vendor items from mock data
	_load_vendor_items()
		
	var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location) if GameInfo.settlements_db else null
	
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

func _load_vendor_items():
	"""Load vendor items from character data"""
	vendor_items.clear()
	
	# Find character data in Websocket.mock_characters
	var char_data: Dictionary = {}
	for character in Websocket.mock_characters:
		if character.character_id == GameInfo.current_character_id:
			char_data = character
			break
	
	if char_data.is_empty() or not char_data.has("vendor_items"):
		return
	
	for item_id in char_data.vendor_items:
		var item = GameInfo.Item.new({
			"id": item_id,
			"day": GameInfo.current_player.server_day if GameInfo.current_player else 1
		})
		vendor_items.append(item)
	
	print("Loaded ", vendor_items.size(), " vendor items")

func trigger_purchase_greeting():
	"""Called by InventorySlot when player purchases from vendor"""
	populate_vendor_slots()
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
	# Hide all vendor slots first and clear them
	for slot in vendor_slots:
		if slot.has_method("clear_slot"):
			slot.clear_slot()
		slot.visible = false
	
	# Populate vendor slots with local vendor_items
	for i in range(min(vendor_items.size(), vendor_slots.size())):
		var item = vendor_items[i]
		var slot = vendor_slots[i]
		slot.visible = true
		item.bag_slot_id = VENDOR_MIN + i
		
		var item_scene = load("res://Scenes/item.tscn")
		if item_scene:
			var icon = item_scene.instantiate()
			icon.set_item_data(item)
			slot.add_child(icon)
