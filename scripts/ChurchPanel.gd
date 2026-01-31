extends Panel

const BLESSING_COST = 10

@export var utility_background_container: Control
@export var blessing_slot_1: TextureRect
@export var blessing_slot_2: TextureRect
@export var blessing_slot_3: TextureRect
@export var effect_description_label: Label
@export var bless_button: Button

var utility_background: UtilityBackground  # Found from loaded utility scene
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
		# Pre-select current active blessing if exists
		if GameInfo.current_player.blessing != 0:
			for i in range(blessing_data.size()):
				if blessing_data[i].id == GameInfo.current_player.blessing:
					_on_blessing_selected(i, blessing_data[i])
					break
		update_bless_button_state()
		utility_background.show_entered_greeting()

func _load_location_content():
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
	if not settlement:
		print("Error: No settlement found for location ", GameInfo.current_player.location)
		return
	
	# Clear existing children from container
	for child in utility_background_container.get_children():
		child.queue_free()
	
	# Load shared utility background scene
	var utility_scene = preload("res://Scenes/UtilityBackground.tscn")
	var utility_instance = utility_scene.instantiate()
	utility_background_container.add_child(utility_instance)
	
	# Set to full rect
	utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	utility_instance.offset_left = 0
	utility_instance.offset_top = 0
	utility_instance.offset_right = 0
	utility_instance.offset_bottom = 0
	
	# Setup from settlement data (utility, not vendor)
	utility_instance.setup_from_settlement(settlement, false)
	
	utility_background = utility_instance

func load_blessings():
	# Clear blessing data
	blessing_data.clear()
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)
	if not settlement:
		print("Error: No settlement found for location ", GameInfo.current_player.location)
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
	
	print("Loaded ", blessing_data.size(), " blessings into 3 slots")

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
			var description_with_factor = effect.description
			if perk.factor1 != 0:
				description_with_factor += " " + str(perk.factor1) + "%"
			effect_text = perk.perk_name + "\n" + description_with_factor
	effect_description_label.text = effect_text
	
	print("Selected blessing: ", perk.perk_name, " (ID: ", perk.id, ")")
	
	update_bless_button_state()

func update_bless_button_state():
	var has_selection = selected_blessing_id != -1
	var has_silver = GameInfo.current_player.silver >= BLESSING_COST
	var is_same_blessing = selected_blessing_id == GameInfo.current_player.blessing
	
	bless_button.disabled = not has_selection or not has_silver or is_same_blessing

func _on_bless_button_pressed():
	Websocket.choose_blessing(selected_blessing_id)
	UIManager.instance.update_silver(-BLESSING_COST)
	GameInfo.current_player.blessing = selected_blessing_id
	print("Received blessing ID: ", selected_blessing_id, " - cost: ", BLESSING_COST, " gold")
	
	utility_background.show_action_greeting()
	UIManager.instance.refresh_active_effects()
	
	# Reload blessings to update highlighting
	load_blessings()
	
	# Show the active blessing's description after blessing
	for i in range(blessing_data.size()):
		if blessing_data[i].id == GameInfo.current_player.blessing:
			_on_blessing_selected(i, blessing_data[i])
			break
	
	update_bless_button_state()
