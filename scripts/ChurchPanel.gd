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
	_load_location_content()
	
	# Setup blessing slots array
	blessing_slots = [blessing_slot_1, blessing_slot_2, blessing_slot_3]
	
	# Connect bless button
	if bless_button:
		bless_button.pressed.connect(_on_bless_button_pressed)
	
	# Load blessings when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		load_blessings()
		# Pre-select current active blessing if exists
		if GameInfo.current_player and GameInfo.current_player.blessing != 0:
			for i in range(blessing_data.size()):
				if blessing_data[i].id == GameInfo.current_player.blessing:
					_on_blessing_selected(i, blessing_data[i])
					break
		update_bless_button_state()
		# Show entered greeting when panel becomes visible
		if utility_background:
			utility_background.show_entered_greeting()

func _load_location_content():
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	
	# Clear existing children from container
	if utility_background_container:
		for child in utility_background_container.get_children():
			child.queue_free()
	
	# Instantiate and add the utility scene
	if location_data.church_utility_scene:
		var utility_instance = location_data.church_utility_scene.instantiate()
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

func load_blessings():
	if not GameInfo.perks_db:
		return
	
	# Clear blessing data
	blessing_data.clear()
	
	# Load all perks with id >= 100 (blessings) - should be exactly 3
	for perk in GameInfo.perks_db.perks:
		if perk.id >= 100:
			blessing_data.append(perk)
	
	# Setup the 3 blessing slots
	for i in range(min(3, blessing_data.size())):
		var perk = blessing_data[i]
		var slot = blessing_slots[i]
		
		if slot and perk:
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
			if GameInfo.current_player and GameInfo.current_player.blessing == perk.id:
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
		if GameInfo.current_player and blessing_data.size() > i and GameInfo.current_player.blessing == blessing_data[i].id:
			slot.modulate = Color(1.2, 1.2, 1.0)  # Keep active blessing highlighted
		else:
			slot.modulate = Color(1, 1, 1)  # Normal
	
	# Highlight selected slot
	blessing_slots[slot_index].modulate = Color(0.8, 1.2, 0.8)  # Green tint for selection
	
	# Update selected blessing
	selected_blessing_id = perk.id
	
	# Update description label with perk name and description with factor
	if effect_description_label and GameInfo.effects_db:
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
	if not bless_button or not GameInfo.current_player:
		return
	
	var has_selection = selected_blessing_id != -1
	var has_silver = GameInfo.current_player.silver >= BLESSING_COST
	var is_same_blessing = selected_blessing_id == GameInfo.current_player.blessing
	
	bless_button.disabled = not has_selection or not has_silver or is_same_blessing

func _on_bless_button_pressed():
	if selected_blessing_id == -1 or not GameInfo.current_player:
		return
	
	if GameInfo.current_player.silver < BLESSING_COST:
		print("Not enough gold for blessing")
		return
	
	# Deduct silver
	UIManager.instance.update_silver(-BLESSING_COST)
	
	# Apply blessing effect
	GameInfo.current_player.blessing = selected_blessing_id
	print("Received blessing ID: ", selected_blessing_id, " - cost: ", BLESSING_COST, " gold")
	
	# Show action greeting after blessing
	if utility_background:
		utility_background.show_action_greeting()
	
	# Refresh active effects and stats
	if UIManager.instance:
		UIManager.instance.refresh_active_effects()
	
	# Reload blessings to update highlighting
	load_blessings()
	
	# Clear selection
	selected_blessing_id = -1
	if effect_description_label:
		effect_description_label.text = ""
	update_bless_button_state()
