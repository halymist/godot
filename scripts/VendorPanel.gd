extends TextureRect

const VENDOR_DISPLAY_SLOT = 21

@export var chat_bubble: ChatBubble
@export var bag: Control
@export var vendor_display: Control
@export var item_scene: PackedScene

var _item_slot_scene = preload("res://Scenes/ItemSlot.tscn")

# Greeting arrays loaded from settlement
var on_entered_greetings: Array[String] = []
var on_sold_greetings: Array[String] = []
var on_bought_greetings: Array[String] = []
var vendor_items: Array[GameInfo.Item] = []

var _vendor_grid: GridContainer  # Dynamically created grid inside vendor_display

func _ready():
	visibility_changed.connect(_on_visibility_changed)
	_create_vendor_grid()
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	populate_vendor_slots()

func _create_vendor_grid():
	if _vendor_grid:
		return
	_vendor_grid = GridContainer.new()
	_vendor_grid.columns = 4
	_vendor_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vendor_grid.add_theme_constant_override("h_separation", 4)
	_vendor_grid.add_theme_constant_override("v_separation", 4)
	_vendor_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vendor_display.add_child(_vendor_grid)

func _on_visibility_changed():
	if visible:
		populate_vendor_slots()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	if not GameInfo.current_player:
		return
	
	_load_vendor_items()
		
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
	if not settlement:
		print("Error: No settlement found for location ", GameInfo.current_player.location)
		return
	
	# Apply vendor texture directly to self
	if settlement.vendor_texture:
		texture = settlement.vendor_texture
	
	# Load vendor greetings from settlement
	on_entered_greetings = settlement.get_vendor_on_entered_lines()
	on_sold_greetings = settlement.get_vendor_on_sold_lines()
	on_bought_greetings = settlement.get_vendor_on_bought_lines()

func _load_vendor_items():
	vendor_items.clear()
	
	if not GameInfo.current_player:
		print("[VendorPanel] No current player")
		return
	
	print("[VendorPanel] Loading vendor items. current_player.vendor_items = ", GameInfo.current_player.vendor_items)
	
	if GameInfo.current_player.vendor_items.is_empty():
		print("[VendorPanel] No vendor items available")
		return
	
	for item_id in GameInfo.current_player.vendor_items:
		print("[VendorPanel] Creating vendor item with id: ", item_id)
		var item = GameInfo.Item.new({
			"id": item_id,
			"day": GameInfo.current_player.server_day
		})
		print("[VendorPanel] Created item: ", item.item_name, " (id=", item.id, ")")
		vendor_items.append(item)

func trigger_purchase_greeting():
	populate_vendor_slots()
	_show_greeting(on_bought_greetings)

func _show_greeting(greetings: Array[String]):
	if not chat_bubble or greetings.is_empty():
		return
	var greeting = greetings[randi() % greetings.size()]
	chat_bubble.show_with_text(greeting, 4.0)

func trigger_sell_greeting():
	populate_vendor_slots()
	_show_greeting(on_sold_greetings)

func _on_bag_slots_changed():
	if visible:
		populate_vendor_slots()

func populate_vendor_slots():
	if not _vendor_grid:
		_create_vendor_grid()
	
	# Clear existing item slots
	for child in _vendor_grid.get_children():
		child.queue_free()
	
	for i in range(vendor_items.size()):
		var item = vendor_items[i]
		item.bag_slot_id = VENDOR_DISPLAY_SLOT + i
		
		# Create a real ItemSlot so drag source_container has slot_id
		var slot = _item_slot_scene.instantiate()
		slot.slot_id = VENDOR_DISPLAY_SLOT + i
		slot.texture = null  # No slot background — items float in the big display
		_vendor_grid.add_child(slot)
		
		var icon = item_scene.instantiate()
		icon.set_item_data(item)
		slot.add_child(icon)
