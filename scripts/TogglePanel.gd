extends Control

@export var home_panel: Control
@export var home_button: Button
@export var arena_panel: Control
@export var arena_button: Button
@export var character_button: Button
@export var character_panel: Control
@export var talents_button: Button
@export var talents_panel: Control
@export var details_panel: Control
@export var details_button: Button
@export var map_button: Button
@export var map_panel: Control
@export var back_button: Button
@export var settings_button: Button
@export var rankings_button: Button
@export var chat_button: Button
@export var chat_panel: Button
@export var combat_panel: Control
@export var settings_panel: Control
@export var rankings_panel: Control
@export var fight_button: Button
@export var interior_view: Control
@export var village_view: Control
@export var quest_panel: Control
@export var quest: Control
@export var cancel_quest: Control
@export var upgrade_talent: Control
@export var perks_panel: Control
@export var vendor_panel: Control
@export var blacksmith_panel: Control
@export var trainer_panel: Control
@export var church_panel: Control
@export var alchemist_panel: Control
@export var enchanter_panel: Control
@export var enemy_panel: Control
@export var enemy: Array[Button] = []
@export var payment: Control
@export var payment_button: Button
@export var avatar_panel: Control
@export var avatar_button: Button

# Track UI state
var chat_overlay_active: bool = false

func _ready():
	# Start with home panel visible
	GameInfo.set_current_panel(home_panel)
	home_panel.visible = true
	
	# Connect button signals
	home_button.pressed.connect(handle_home_button)
	arena_button.pressed.connect(handle_arena_button)
	character_button.pressed.connect(handle_character_button)
	map_button.pressed.connect(handle_map_button)
	rankings_button.pressed.connect(handle_rankings_button)
	talents_button.pressed.connect(toggle_talents_bookmark)
	details_button.pressed.connect(toggle_details_bookmark)
	settings_button.pressed.connect(show_overlay.bind(settings_panel))
	payment_button.pressed.connect(show_overlay.bind(payment))
	chat_button.pressed.connect(show_overlay.bind(chat_panel))
	back_button.pressed.connect(go_back)
	fight_button.pressed.connect(show_combat)
	avatar_button.pressed.connect(show_overlay.bind(avatar_panel))
	
	# Connect enemy buttons to show enemy panel overlay
	for button in enemy:
		button.pressed.connect(show_overlay.bind(enemy_panel))
	
	# Connect cancel quest dialog buttons
	var yes_button = cancel_quest.get_node("DialogPanel/VBoxContainer/HBoxContainer/YesButton")
	var no_button = cancel_quest.get_node("DialogPanel/VBoxContainer/HBoxContainer/NoButton")
	var background_button = cancel_quest.get_node("BackgroundButton")
	yes_button.pressed.connect(_on_cancel_quest_yes)
	no_button.pressed.connect(_on_cancel_quest_no)
	background_button.pressed.connect(_on_cancel_quest_no)

func show_overlay(overlay: Control):
	"""Show overlay on top of current panel"""
	# Chat special handling
	if overlay == chat_panel:
		if chat_overlay_active:
			hide_overlay(chat_panel)
			return
		else:
			chat_overlay_active = true
	
	# Hide current overlay if different
	var current = GameInfo.get_current_panel_overlay()
	if current != null and current != overlay:
		hide_overlay(current)
	
	# Toggle off if same overlay
	if current == overlay:
		hide_overlay(overlay)
		return
	
	# Show new overlay
	GameInfo.set_current_panel_overlay(overlay)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = true
	
func hide_overlay(overlay: Control):
	"""Hide overlay"""
	if overlay == chat_panel:
		chat_overlay_active = false
	
	if GameInfo.get_current_panel_overlay() == overlay:
		GameInfo.set_current_panel_overlay(null)
	
	overlay.visible = false

func show_panel(panel: Control):
	"""Show main panel - hides all overlays and current panel"""
	# Hide current panel
	var current_panel = GameInfo.get_current_panel()
	if current_panel:
		current_panel.visible = false
		
		# Reset home panel to default view when leaving it
		if current_panel == home_panel:
			home_panel.handle_back_navigation()
			home_panel.center_village_view()
	
	# Hide current overlay
	var current_overlay = GameInfo.get_current_panel_overlay()
	if current_overlay:
		hide_overlay(current_overlay)
	
	# Hide chat overlay
	if chat_overlay_active:
		chat_overlay_active = false
		chat_panel.visible = false
	
	# Show new panel
	panel.visible = true
	GameInfo.set_current_panel(panel)
	

func handle_home_button():
	"""Navigate to home panel - with custom home panel behavior"""
	# Custom home panel behavior: exit interior and center view
	home_panel.handle_back_navigation()
	home_panel.center_village_view()
	
	# Show home panel
	show_panel(home_panel)

func handle_map_button():
	"""Navigate to map panel - with custom quest logic"""
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	var current = GameInfo.get_current_panel()
	
	# Toggle off if already on map
	if current == map_panel:
		show_panel(home_panel)
		return
	
	# Quest states
	if traveling > 0 and destination != null:
		show_panel(map_panel)  # Traveling
	elif traveling == null and destination != null:
		show_panel(quest)  # Quest available
	else:
		show_panel(map_panel)  # Normal map

func handle_arena_button():
	"""Toggle arena panel"""
	if GameInfo.get_current_panel() == arena_panel:
		show_panel(home_panel)
	else:
		show_panel(arena_panel)

func handle_character_button():
	"""Toggle character panel"""
	if GameInfo.get_current_panel() == character_panel:
		show_panel(home_panel)
	else:
		show_panel(character_panel)

func handle_rankings_button():
	"""Toggle rankings panel"""
	if GameInfo.get_current_panel() == rankings_panel:
		show_panel(home_panel)
	else:
		show_panel(rankings_panel)

func toggle_talents_bookmark():
	if GameInfo.get_current_panel() == talents_panel:
		talents_panel.visible = false
		GameInfo.set_current_panel(character_panel)
	else:
		talents_panel.visible = true
		GameInfo.set_current_panel(talents_panel)

func toggle_details_bookmark():
	if GameInfo.get_current_panel() == details_panel:
		details_panel.visible = false
		GameInfo.set_current_panel(character_panel)
	else:
		details_panel.visible = true
		GameInfo.set_current_panel(details_panel)


func go_back():
	"""Back button - priority: chat > overlay > panel custom behavior > home"""
	var current = GameInfo.get_current_panel()
	
	# Priority 1: Hide chat overlay
	if chat_overlay_active and chat_panel.visible:
		hide_overlay(chat_panel)
		return
	
	# Priority 2: Hide current overlay
	var current_overlay = GameInfo.get_current_panel_overlay()
	if current_overlay and current_overlay.visible:
		hide_overlay(current_overlay)
		return
	
	# Priority 3: Panel-specific custom back behavior
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	
	# Map panel: show cancel quest if traveling
	if current == map_panel:
		if traveling > 0 and destination != null:
			show_overlay(cancel_quest)
			return
	
	# Quest panel: show cancel quest if arrived
	if current == quest:
		if traveling == 0 and destination != null:
			show_overlay(cancel_quest)
			return
	
	# Home panel: check for interior navigation
	if current == home_panel:
		var handled = home_panel.handle_back_navigation()
		if handled:
			return
	
	# Talents/Details bookmarks
	if current == talents_panel:
		toggle_talents_bookmark()
		return
	if current == details_panel:
		toggle_details_bookmark()
		return
	
	# Combat: return to arena
	if current == combat_panel:
		show_panel(arena_panel)
		return
	
	# Default: go home
	show_panel(home_panel)


func show_combat():
	"""Show combat panel"""
	var current_panel = GameInfo.get_current_panel()
	if current_panel:
		current_panel.visible = false
	combat_panel.visible = true
	GameInfo.set_current_panel(combat_panel)

# Cancel quest dialog functions
func _on_cancel_quest_yes():
	# Get the quest ID before clearing it
	var quest_id = GameInfo.current_player.traveling_destination
	
	# Mark quest as completed so NPC won't show up again
	if quest_id != null and quest_id is int:
		GameInfo.complete_quest(quest_id)
		print("Quest ", quest_id, " abandoned and marked as completed")
	
	# Cancel the quest
	GameInfo.current_player.traveling = 0
	GameInfo.current_player.traveling_destination = null
	
	# Hide cancel dialog using unified overlay system and return to home
	hide_overlay(cancel_quest)
	show_panel(home_panel)
	print("Quest canceled by user")

func _on_cancel_quest_no():
	# Just hide the dialog using unified overlay system, continue with quest
	hide_overlay(cancel_quest)
