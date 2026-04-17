extends TextureRect

# Simple Village/Home Panel
# Just displays village image + overlay with buttons
# No scrolling, no NPCs, no interiors

@export var chat_bubble: ChatBubble

# Static buttons in scene
@export var vendor_button: Button
@export var vendor_icon: TextureRect
@export var vendor_label: Label
@export var utility_button: Button
@export var utility_icon: TextureRect
@export var utility_label: Label

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

func _ready():
	# Refresh quest display whenever village becomes visible again
	visibility_changed.connect(_on_visibility_changed)
	# Wait for game_ready before setup
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _on_visibility_changed():
	if visible and GameInfo.current_player:
		_update_quest_display()

func _setup():
	if not GameInfo.current_player:
		print("VillagePanel: No character selected yet")
		return
	
	_load_village_background()
	_setup_buttons()
	_update_quest_display()
	
	# Connect button signals
	if vendor_button and not vendor_button.pressed.is_connected(_on_vendor_pressed):
		vendor_button.pressed.connect(_on_vendor_pressed)
	if utility_button and not utility_button.pressed.is_connected(_on_utility_pressed):
		utility_button.pressed.connect(_on_utility_pressed)
	if quest_button and not quest_button.pressed.is_connected(_on_quest_button_pressed):
		quest_button.pressed.connect(_on_quest_button_pressed)
	if quest_arrow and not quest_arrow.pressed.is_connected(_on_quest_arrow_pressed):
		quest_arrow.pressed.connect(_on_quest_arrow_pressed)

func _load_village_background():
	"""Load village background image from current location"""
	var location_id = GameInfo.current_player.location
	var settlement = GameInfo.settlements_db.get_settlement_by_id(location_id)
	
	# Apply settlement texture directly to self as village background
	if settlement and settlement.settlement_texture:
		texture = settlement.settlement_texture
	
	# Update location name label in overlay
	if location_label and settlement:
		location_label.text = settlement.location_name if settlement.location_name else "Unknown"
	
	# Update location description (italic) in overlay
	if location_description_label and settlement:
		location_description_label.text = settlement.description if settlement.description else ""

func _setup_buttons():
	"""Configure vendor and utility buttons based on settlement"""
	var location_id = GameInfo.current_player.location
	var settlement = GameInfo.settlements_db.get_settlement_by_id(location_id)
	
	if not settlement:
		return
	
	# Vendor button - always show if available
	if vendor_button:
		vendor_button.visible = settlement.has_vendor()
	
	# Utility button - configure based on what's available
	if utility_button:
		if settlement.has_blacksmith():
			_configure_utility("Blacksmith", "res://assets/images/ui/blacksmith_icon.png")
		elif settlement.has_enchanter():
			_configure_utility("Enchanter", "res://assets/images/ui/enchanter_icon.png")
		elif settlement.has_alchemist():
			_configure_utility("Alchemist", "res://assets/images/ui/alchemist_icon.png")
		elif settlement.has_church():
			_configure_utility("Church", "res://assets/images/ui/church_icon.png")
		elif settlement.has_trainer():
			_configure_utility("Trainer", "res://assets/images/ui/trainer_icon.png")
		else:
			utility_button.visible = false

func _configure_utility(type_name: String, icon_path: String):
	"""Configure the utility button appearance"""
	_utility_type = type_name
	if utility_label:
		utility_label.text = type_name
	if utility_icon and ResourceLoader.exists(icon_path):
		utility_icon.texture = load(icon_path)
	utility_button.visible = true

func _update_quest_display():
	"""Update quest button to show current quest info"""
	available_quests.clear()
	
	# Get daily quests that aren't finished
	if GameInfo.current_player:
		var daily_quests = GameInfo.current_player.daily_quests
		var quest_log = GameInfo.current_player.quest_log
		
		for quest_id in daily_quests:
			var is_finished = false
			for entry in quest_log:
				if entry.get("quest_id", 0) == quest_id and entry.get("finished", false):
					is_finished = true
					break
			if not is_finished:
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
	match _utility_type:
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
