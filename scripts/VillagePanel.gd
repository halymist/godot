extends TextureRect

# Simple Village/Home Panel
# Just displays village image + overlay with buttons
# No scrolling, no NPCs, no interiors

@export var chat_bubble: ChatBubble
@export var image_area: TextureRect

# Static buttons in scene
@export var vendor_button: Button
@export var vendor_icon: TextureRect
@export var vendor_label: Label
@export var utility_button: Button
@export var utility_icon: TextureRect
@export var utility_label: Label
@export var secondary_utility_button: Button
@export var secondary_utility_icon: TextureRect
@export var secondary_utility_label: Label
@export var healer_button: Button
@export var healer_icon: TextureRect
@export var healer_label: Label

# Quest button
@export var quest_button: Button
@export var quest_icon: TextureRect
@export var quest_name_label: Label
@export var quest_progress_label: Label
@export var quest_arrow: Button

# Child panels that exist under Home (for compatibility)
@export var quest_slide_panel: Control
@export var map_panel: Control
@export var location_label: Label
@export var location_description_label: Label

# Current quest tracking
var current_quest_index: int = 0
var available_quests: Array[int] = []
var _utility_type: String = ""  # Track current utility type for callback
var _secondary_utility_type: String = ""

func _ready():
	_connect_buttons()
	# Refresh quest display whenever village becomes visible again
	visibility_changed.connect(_on_visibility_changed)
	# Wait for game_ready before setup
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _on_visibility_changed():
	_connect_buttons()
	if visible and GameInfo.current_player:
		_load_village_background()
		_setup_buttons()
		_update_quest_display()

func _setup():
	_connect_buttons()
	if not GameInfo.current_player:
		return
	
	_load_village_background()
	_setup_buttons()
	_update_quest_display()

func _connect_buttons():
	# Connect button signals
	if vendor_button and not vendor_button.pressed.is_connected(_on_vendor_pressed):
		vendor_button.pressed.connect(_on_vendor_pressed)
	if utility_button and not utility_button.pressed.is_connected(_on_utility_pressed):
		utility_button.pressed.connect(_on_utility_pressed)
	if secondary_utility_button and not secondary_utility_button.pressed.is_connected(_on_secondary_utility_pressed):
		secondary_utility_button.pressed.connect(_on_secondary_utility_pressed)
	if healer_button and not healer_button.pressed.is_connected(_on_healer_pressed):
		healer_button.pressed.connect(_on_healer_pressed)
	if quest_button and not quest_button.pressed.is_connected(_on_quest_button_pressed):
		quest_button.pressed.connect(_on_quest_button_pressed)
	if quest_arrow and not quest_arrow.pressed.is_connected(_on_quest_arrow_pressed):
		quest_arrow.pressed.connect(_on_quest_arrow_pressed)

func _load_village_background():
	"""Load village background image from current location"""
	if not GameInfo.current_player or not GameInfo.settlements_db:
		return

	var location_id = GameInfo.current_player.location
	var settlement = GameInfo.settlements_db.get_settlement_by_id(location_id)
	
	var settlement_texture = settlement.get_settlement_texture() if settlement else null
	if settlement_texture:
		if image_area:
			image_area.texture = settlement_texture
		else:
			texture = settlement_texture
	
	# Update location name label in overlay
	if location_label and settlement:
		location_label.text = settlement.location_name if settlement.location_name else "Unknown"
	
	# Update location description (italic) in overlay
	if location_description_label:
		location_description_label.text = settlement.description if settlement and settlement.description else "No description available."

func _setup_buttons():
	"""Configure vendor and utility buttons based on settlement"""
	var location_id = GameInfo.current_player.location
	var settlement = GameInfo.settlements_db.get_settlement_by_id(location_id)
	
	if not settlement:
		return

	# Reset utility state before selecting the active one for this settlement.
	_utility_type = ""
	_secondary_utility_type = ""
	if utility_label:
		utility_label.text = ""
	if utility_icon:
		utility_icon.texture = null
	if secondary_utility_label:
		secondary_utility_label.text = ""
	if secondary_utility_icon:
		secondary_utility_icon.texture = null
	if secondary_utility_button:
		secondary_utility_button.visible = false
		secondary_utility_button.disabled = true
	if healer_label:
		healer_label.text = "Healer"
	if healer_button:
		healer_button.visible = settlement.has_healer()
	
	# Vendor button - always show if available
	if vendor_button:
		vendor_button.visible = settlement.has_vendor()
	
	_configure_utility_button(settlement.get_utility_slot(1), utility_button, utility_icon, utility_label, false)
	_configure_utility_button(settlement.get_utility_slot(2), secondary_utility_button, secondary_utility_icon, secondary_utility_label, true)

func _configure_utility_button(utility_data: Dictionary, button: Button, icon: TextureRect, label: Label, is_secondary: bool):
	if not button:
		return
	if utility_data.is_empty():
		button.visible = false
		button.disabled = true
		return

	var type_name = _utility_display_name(str(utility_data.get("type", "")))
	var icon_path = _utility_icon_path(type_name)
	if is_secondary:
		_secondary_utility_type = type_name
	else:
		_utility_type = type_name
	_configure_utility(button, icon, label, type_name, icon_path)

func _configure_utility(button: Button, icon: TextureRect, label: Label, type_name: String, icon_path: String):
	"""Configure the utility button appearance"""
	if label:
		label.text = type_name
	if icon and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	button.visible = true
	button.disabled = false

func _utility_display_name(raw_type: String) -> String:
	match raw_type.to_lower():
		"blacksmith": return "Blacksmith"
		"enchanter": return "Enchanter"
		"alchemist": return "Alchemist"
		"church": return "Church"
		"trainer": return "Trainer"
		_: return raw_type.capitalize()

func _utility_icon_path(type_name: String) -> String:
	match type_name:
		"Blacksmith": return "res://assets/images/ui/blacksmith_icon.png"
		"Enchanter": return "res://assets/images/ui/enchanter_icon.png"
		"Alchemist": return "res://assets/images/ui/alchemist_icon.png"
		"Church": return "res://assets/images/ui/church_icon.png"
		"Trainer": return "res://assets/images/ui/trainer_icon.png"
		_: return ""

func _update_quest_display():
	"""Update quest button to show current quest info"""
	available_quests.clear()
	
	# Get daily quests that aren't finished
	if GameInfo.current_player:
		var daily_quests = GameInfo.current_player.daily_quests
		var quest_log = GameInfo.current_player.quest_log
		
		for quest_id in daily_quests:
			var was_attempted = false
			for entry in quest_log:
				if int(entry.get("quest_id", 0)) == int(quest_id):
					was_attempted = true
					break
			if not was_attempted:
				available_quests.append(quest_id)
	
	if not quest_button:
		return
	
	# Handle no quests
	if available_quests.size() == 0:
		if quest_name_label:
			quest_name_label.text = "No quests available"
		if quest_progress_label:
			quest_progress_label.visible = false
		if quest_arrow:
			quest_arrow.visible = false
		quest_button.disabled = true
		return
	
	quest_button.disabled = false
	current_quest_index = clamp(current_quest_index, 0, available_quests.size() - 1)
	
	# Get current quest data
	var quest_id = available_quests[current_quest_index]
	var quest_data = GameInfo.quests_db.get_quest_by_id(quest_id)
	
	if quest_data and quest_name_label:
		quest_name_label.text = quest_data.quest_name
	
	# Show progress indicator
	if quest_progress_label:
		if available_quests.size() > 1:
			quest_progress_label.text = str(current_quest_index + 1) + " / " + str(available_quests.size())
			quest_progress_label.visible = true
		else:
			quest_progress_label.visible = false
	
	# Show arrow if multiple quests
	if quest_arrow:
		quest_arrow.visible = available_quests.size() > 1

func _on_quest_button_pressed():
	"""Handle quest button press - start travel"""
	if available_quests.size() == 0:
		return
	
	var quest_id = available_quests[current_quest_index]
	var quest_data = GameInfo.quests_db.get_quest_by_id(quest_id)
	
	if quest_data:
		var travel_text = quest_data.travel_text if quest_data.travel_text else "Traveling..."
		UIManager.instance.map_panel.start_travel(travel_text, 20, quest_id)
		UIManager.instance.show_panel(UIManager.instance.map_panel)

func _on_quest_arrow_pressed():
	"""Cycle to next quest"""
	if available_quests.size() > 1:
		current_quest_index = (current_quest_index + 1) % available_quests.size()
		_update_quest_display()

func _on_vendor_pressed():
	UIManager.instance.show_panel(UIManager.instance.vendor_panel)

func _on_utility_pressed():
	"""Handle utility button press based on configured type"""
	_open_utility_slot(1, _utility_type)

func _on_secondary_utility_pressed():
	_open_utility_slot(2, _secondary_utility_type)

func _open_utility_slot(slot: int, type_name: String):
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location) if GameInfo.settlements_db and GameInfo.current_player else null
	if not settlement or not settlement.select_utility_slot(slot):
		return
	match type_name:
		"Blacksmith":
			UIManager.instance.show_panel(UIManager.instance.blacksmith_panel)
		"Enchanter":
			UIManager.instance.show_panel(UIManager.instance.enchanter_panel)
		"Alchemist":
			UIManager.instance.show_panel(UIManager.instance.alchemist_panel)
		"Church":
			UIManager.instance.show_panel(UIManager.instance.church_panel)
		"Trainer":
			UIManager.instance.show_panel(UIManager.instance.trainer_panel)

func _on_healer_pressed():
	UIManager.instance.show_panel(UIManager.instance.healer_panel)

func refresh_quests():
	"""Call when quests change"""
	_update_quest_display()

func refresh_location():
	"""Call when player changes location"""
	_load_village_background()
	_setup_buttons()
	_update_quest_display()

# Stub method for compatibility with TogglePanel
func handle_back_navigation() -> bool:
	return false
