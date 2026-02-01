extends TextureRect

const VENDOR_MIN = 21
const VENDOR_MAX = 28

@export var chat_bubble: ChatBubble
@export var bag: Control
@export var vendor_grid: GridContainer
@export var vendor_slots: Array[Control] = []
@export var item_scene: PackedScene

# Greeting arrays loaded from settlement
var on_entered_greetings: Array[String] = []
var on_sold_greetings: Array[String] = []
var on_bought_greetings: Array[String] = []
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
	_show_greeting(on_bought_greetings)

func _show_greeting(greetings: Array[String]):
	if not chat_bubble or greetings.is_empty():
		return
	var greeting = greetings[randi() % greetings.size()]
	chat_bubble.show_with_text(greeting, 4.0)

func trigger_sell_greeting():
	_show_greeting(on_sold_greetings)

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
