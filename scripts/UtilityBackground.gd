extends Control
class_name UtilityBackground

# Simple utility background with a texture and chat bubble
# Greetings are now loaded from Settlement data (not stored in scene)

@export var background_texture: TextureRect
@export var chat_bubble: ChatBubble

# Runtime greeting arrays (set by panel when loading settlement)
var on_entered_greetings: Array[String] = []
var on_item_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []

@export var greeting_duration: float = 4.0
@export var cooldown_between_messages: float = 5.0

var last_message_time: float = -999.0  # Time when last message was shown

func setup_from_settlement(settlement_or_id, is_vendor: bool = false):
	# Accept either a Settlement instance or a location_id
	var settlement = settlement_or_id
	if typeof(settlement_or_id) == TYPE_INT:
		# Look up the settlement from the database
		settlement = GameInfo.settlements_db.get_settlement_by_id(settlement_or_id)
	if not settlement:
		push_error("UtilityBackground: Could not find settlement in database!")
		return
	# Set up greetings and texture from settlement data
	if is_vendor:
		# Vendor greetings
		on_entered_greetings = settlement.get_vendor_on_entered_lines()
		on_item_placed_greetings = settlement.get_vendor_on_sold_lines()  # sold = placed in vendor
		on_action_greetings = settlement.get_vendor_on_bought_lines()  # bought = action
		if settlement.vendor_texture and background_texture:
			background_texture.texture = settlement.vendor_texture
	else:
		# Utility greetings
		on_entered_greetings = settlement.get_utility_on_entered_lines()
		on_item_placed_greetings = settlement.get_utility_on_placed_lines()
		on_action_greetings = settlement.get_utility_on_action_lines()
		if settlement.utility_texture and background_texture:
			background_texture.texture = settlement.utility_texture

func show_entered_greeting():
	if not chat_bubble or on_entered_greetings.is_empty():
		return
	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_message_time < cooldown_between_messages:
		return  # Still in cooldown, skip showing message
	
	var greeting = on_entered_greetings[randi() % on_entered_greetings.size()]
	chat_bubble.show_with_text(greeting, greeting_duration)
	last_message_time = current_time

func show_item_placed_greeting():
	if not chat_bubble or on_item_placed_greetings.is_empty():
		return
	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_message_time < cooldown_between_messages:
		return  # Still in cooldown, skip showing message
	
	var greeting = on_item_placed_greetings[randi() % on_item_placed_greetings.size()]
	chat_bubble.show_with_text(greeting, greeting_duration)
	last_message_time = current_time

func show_action_greeting():
	if not chat_bubble or on_action_greetings.is_empty():
		return
	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_message_time < cooldown_between_messages:
		return  # Still in cooldown, skip showing message
	
	var greeting = on_action_greetings[randi() % on_action_greetings.size()]
	chat_bubble.show_with_text(greeting, greeting_duration)
	last_message_time = current_time
