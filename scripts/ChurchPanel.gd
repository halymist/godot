extends TextureRect

const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")

const BLESSING_COST = 10
const COLOR_PRICE_NORMAL = Color(0.85, 0.8, 0.7, 1.0)
const COLOR_PRICE_MISSING = Color(1.0, 0.25, 0.2, 1.0)

@export var chat_bubble: ChatBubble
@export var image_area: TextureRect
@export var blessing_slot_1: TextureRect
@export var blessing_slot_2: TextureRect
@export var blessing_slot_3: TextureRect
@export var effect_description_label: Label
@export var bless_button: Button

var on_entered_greetings: Array[String] = []
var on_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []
var selected_blessing_id: int = -1
var blessing_slots: Array[TextureRect] = []
var blessing_data: Array = []  # Stores the 3 blessing PerkResources

func _ready():
	# Setup blessing slots array
	blessing_slots = [blessing_slot_1, blessing_slot_2, blessing_slot_3]
	bless_button.pressed.connect(_on_bless_button_pressed)
	visibility_changed.connect(_on_visibility_changed)
	
	# Wait for game to be ready
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	load_blessings()

func _on_visibility_changed():
	if visible:
		_load_location_content()
		load_blessings()
		# Pre-select current active blessing if exists
		if GameInfo.current_player.blessing != 0:
			for i in range(blessing_data.size()):
				if blessing_data[i].id == GameInfo.current_player.blessing:
					_on_blessing_selected(i, blessing_data[i])
					break
		update_bless_button_state()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
	if not settlement:
		return
	
	var utility_texture = settlement.get_utility_texture()
	if utility_texture:
		if image_area:
			image_area.texture = utility_texture
			texture = null
		else:
			texture = utility_texture
	
	# Load utility greetings from settlement
	on_entered_greetings = settlement.get_utility_on_entered_lines()
	on_placed_greetings = settlement.get_utility_on_placed_lines()
	on_action_greetings = settlement.get_utility_on_action_lines()

	if chat_bubble:
		if settlement.has_utility_msg_rect():
			chat_bubble.set_message_bounds(settlement.utility_msg_bottom_left, settlement.utility_msg_bottom_right)
		else:
			chat_bubble.clear_message_bounds()

func _show_greeting(greetings: Array[String]):
	if not chat_bubble or greetings.is_empty():
		return
	var greeting = greetings[randi() % greetings.size()]
	chat_bubble.show_with_text(greeting, 4.0)

func load_blessings():
	# Clear blessing data
	blessing_data.clear()
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
	if not settlement:
		return
	
	# Load the 3 blessing perks from settlement's blessing IDs
	var blessings = settlement.get_blessings()
	for blessing_id in blessings:
		var perk = GameInfo.perks_db.get_perk_by_id(blessing_id)
		if perk:
			blessing_data.append(perk)
	
	# Setup the 3 blessing slots
	for i in range(min(3, blessing_data.size())):
		var perk = blessing_data[i]
		var slot = blessing_slots[i]
		
		# Clear previous children
		for child in slot.get_children():
			child.queue_free()
		
		# Create blessing icon as child of slot
		var icon_rect = TextureRect.new()
		icon_rect.texture = perk.icon
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(icon_rect)
		
		# Make slot clickable
		if not slot.gui_input.is_connected(_on_blessing_slot_clicked):
			slot.gui_input.connect(_on_blessing_slot_clicked.bind(i, perk))
		
		# Highlight if this is the active blessing
		if GameInfo.current_player.blessing == perk.id:
			slot.modulate = Color(1.2, 1.2, 1.0)  # Yellow tint for active
		else:
			slot.modulate = Color(1, 1, 1)  # Normal
	

func _on_blessing_slot_clicked(event: InputEvent, slot_index: int, perk: PerkResource):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_blessing_selected(slot_index, perk)

func _on_blessing_selected(slot_index: int, perk: PerkResource):
	# Clear previous selection visual
	for i in range(blessing_slots.size()):
		var slot = blessing_slots[i]
		if blessing_data.size() > i and GameInfo.current_player.blessing == blessing_data[i].id:
			slot.modulate = Color(1.2, 1.2, 1.0)  # Keep active blessing highlighted
		else:
			slot.modulate = Color(1, 1, 1)  # Normal
	
	# Highlight selected slot
	blessing_slots[slot_index].modulate = Color(0.8, 1.2, 0.8)  # Green tint for selection
	selected_blessing_id = perk.id
	
	# Update description label with perk name and description with factor
	var effect_text = ""
	if perk.effect1_id > 0:
		var effect = GameInfo.effects_db.get_effect_by_id(perk.effect1_id)
		if effect:
			var description_with_factor = EFFECT_FORMATTER.format_with_factor(effect.description, perk.factor1, true)
			effect_text = perk.perk_name + "\n" + description_with_factor
	effect_description_label.text = effect_text
	
	
	update_bless_button_state()

func update_bless_button_state():
	var has_selection = selected_blessing_id != -1
	var has_silver = GameInfo.current_player.silver >= BLESSING_COST
	var is_same_blessing = selected_blessing_id == GameInfo.current_player.blessing
	
	bless_button.disabled = not has_selection or not has_silver or is_same_blessing
	_set_price_label_color(bless_button, has_silver)

func _set_price_label_color(button: Button, can_afford: bool):
	var price_label = button.get_node_or_null("Content/PriceLabel") as Label
	if price_label:
		price_label.add_theme_color_override("font_color", COLOR_PRICE_NORMAL if can_afford else COLOR_PRICE_MISSING)

func _on_bless_button_pressed():
	Websocket.choose_blessing(selected_blessing_id)
	UIManager.instance.update_silver(-BLESSING_COST)
	GameInfo.current_player.blessing = selected_blessing_id
	
	_show_greeting(on_action_greetings)
	UIManager.instance.refresh_active_effects()
	
	# Reload blessings to update highlighting
	load_blessings()
	
	# Show the active blessing's description after blessing
	for i in range(blessing_data.size()):
		if blessing_data[i].id == GameInfo.current_player.blessing:
			_on_blessing_selected(i, blessing_data[i])
			break
	
	update_bless_button_state()
