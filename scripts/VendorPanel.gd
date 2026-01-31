extends Panel

const VENDOR_MIN = 21
const VENDOR_MAX = 28

@export var utility_background_container: Control
@export var bag: Control
@export var vendor_grid: GridContainer
@export var vendor_slots: Array[Control] = []
@export var item_scene: PackedScene

var utility_background: UtilityBackground
var vendor_items: Array[GameInfo.Item] = []

func _ready():
	visibility_changed.connect(_on_visibility_changed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	populate_vendor_slots()

func _on_visibility_changed():
	if visible:
		populate_vendor_slots()
		utility_background.show_entered_greeting()

func _load_location_content():
	if not GameInfo.current_player:
		return
	
	_load_vendor_items()
		
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
	if not settlement:
		print("Error: No settlement found for location ", GameInfo.current_player.location)
		return
	
	for child in utility_background_container.get_children():
		child.queue_free()
	
	# Load shared utility background scene
	var utility_scene = preload("res://Scenes/UtilityBackground.tscn")
	var utility_instance = utility_scene.instantiate()
	utility_background_container.add_child(utility_instance)
	
	utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	utility_instance.offset_left = 0
	utility_instance.offset_top = 0
	utility_instance.offset_right = 0
	utility_instance.offset_bottom = 0
	
	# Setup from settlement data (vendor, not utility)
	utility_instance.setup_from_settlement(settlement, true)
	
	utility_background = utility_instance

func _load_vendor_items():
	vendor_items.clear()
	
	# Vendor items are now stored in current_player.vendor_items (loaded from server)
	if not GameInfo.current_player or GameInfo.current_player.vendor_items.is_empty():
		print("No vendor items available")
		return
	
	for item_id in GameInfo.current_player.vendor_items:
		var item = GameInfo.Item.new({
			"id": item_id,
			"day": GameInfo.current_player.server_day
		})
		vendor_items.append(item)

func trigger_purchase_greeting():
	populate_vendor_slots()
	utility_background.show_action_greeting()

func trigger_sell_greeting():
	utility_background.show_item_placed_greeting()

func _on_bag_slots_changed():
	if visible:
		populate_vendor_slots()

func populate_vendor_slots():
	for slot in vendor_slots:
		slot.clear_slot()
		slot.visible = false
	
	for i in range(min(vendor_items.size(), vendor_slots.size())):
		var item = vendor_items[i]
		var slot = vendor_slots[i]
		slot.visible = true
		item.bag_slot_id = VENDOR_MIN + i
		
		var icon = item_scene.instantiate()
		icon.set_item_data(item)
		slot.add_child(icon)
