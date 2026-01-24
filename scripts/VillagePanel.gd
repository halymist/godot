extends Panel

# Simple Village/Home Panel
# Just displays village image + overlay with buttons
# No scrolling, no NPCs, no interiors

@export var village_image: TextureRect
@export var buttons_container: VBoxContainer
@export var quest_button: Button
@export var quest_icon: TextureRect
@export var quest_name_label: Label
@export var quest_progress_label: Label
@export var quest_arrow: Button

# Child panels that exist under Home (for compatibility)
@export var quest_panel: Control  # QuestAccept panel
@export var quest_slide_panel: Control
@export var map_panel: Control

# Current quest tracking
var current_quest_index: int = 0
var available_quests: Array[int] = []
var buttons_initialized: bool = false

func _ready():
	# Check if we're the starter panel
	if UIManager.instance.starter_panel == self:
		_setup()
		UIManager.instance.game_is_ready = true
		UIManager.instance.game_ready.emit()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	if not GameInfo.current_player:
		print("VillagePanel: No character selected yet")
		return
	
	_load_village_background()
	_setup_utility_buttons()
	_update_quest_display()
	
	# Connect quest button signals
	if quest_button and not quest_button.pressed.is_connected(_on_quest_button_pressed):
		quest_button.pressed.connect(_on_quest_button_pressed)
	if quest_arrow and not quest_arrow.pressed.is_connected(_on_quest_arrow_pressed):
		quest_arrow.pressed.connect(_on_quest_arrow_pressed)

func _load_village_background():
	"""Load village background image from current location"""
	var location_id = GameInfo.current_player.location
	var location_data = GameInfo.settlements_db.get_location_by_id(location_id)
	
	if location_data and location_data.village_texture and village_image:
		village_image.texture = location_data.village_texture

func _setup_utility_buttons():
	"""Setup utility buttons based on current location"""
	if buttons_initialized:
		return
	buttons_initialized = true
	
	var location_id = GameInfo.current_player.location
	var location_data = GameInfo.settlements_db.get_location_by_id(location_id)
	
	if not location_data or not buttons_container:
		return
	
	# Add Vendor button (always available)
	if location_data.has_vendor():
		_add_button("Vendor", "res://assets/images/ui/vendor_icon.png", _on_vendor_pressed)
	
	# Add utility buttons based on availability
	if location_data.has_church():
		_add_button("Church", "res://assets/images/ui/church_icon.png", _on_church_pressed)
	
	if location_data.has_trainer():
		_add_button("Trainer", "res://assets/images/ui/trainer_icon.png", _on_trainer_pressed)
	
	if location_data.has_blacksmith():
		_add_button("Blacksmith", "res://assets/images/ui/blacksmith_icon.png", _on_blacksmith_pressed)
	
	if location_data.has_enchanter():
		_add_button("Enchanter", "res://assets/images/ui/enchanter_icon.png", _on_enchanter_pressed)
	
	if location_data.has_alchemist():
		_add_button("Alchemist", "res://assets/images/ui/alchemist_icon.png", _on_alchemist_pressed)

func _add_button(text: String, icon_path: String, callback: Callable):
	"""Create and add a utility button"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create HBox for icon + label
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	
	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	hbox.add_child(icon)
	
	# Label
	var label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1))
	hbox.add_child(label)
	
	button.add_child(hbox)
	button.pressed.connect(callback)
	
	# Insert before quest button (quest should be last)
	var quest_idx = quest_button.get_index() if quest_button else buttons_container.get_child_count()
	buttons_container.add_child(button)
	buttons_container.move_child(button, quest_idx)

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

func _on_church_pressed():
	UIManager.instance.show_panel(UIManager.instance.church_panel)

func _on_trainer_pressed():
	UIManager.instance.show_panel(UIManager.instance.trainer_panel)

func _on_blacksmith_pressed():
	UIManager.instance.show_panel(UIManager.instance.blacksmith_panel)

func _on_enchanter_pressed():
	UIManager.instance.show_panel(UIManager.instance.enchanter_panel)

func _on_alchemist_pressed():
	UIManager.instance.show_panel(UIManager.instance.alchemist_panel)

func refresh_quests():
	"""Call when quests change"""
	_update_quest_display()

func refresh_location():
	"""Call when player changes location"""
	buttons_initialized = false
	_load_village_background()
	_setup_utility_buttons()
	_update_quest_display()

# Stub methods for compatibility with TogglePanel
func handle_back_navigation() -> bool:
	return false

func center_village_view():
	pass
