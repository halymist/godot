extends Control

@export var home_panel: Control
@export var home_button: Button
@export var arena_panel: Control
@export var arena_button: Button
@export var character_button: Button
@export var character_panel: Control
@export var talents_button: Button
@export var talents_panel: Control
@export var map_button: Button
@export var map_panel: Control
@export var back_button: Button
@export var chat_button: Button
@export var chat_panel: Control
@export var combat_panel: Control
@export var fight_button: Button
@export var interior_view: Control
@export var village_view: Control
@export var quest_panel: Control
@export var quest: Control
@export var cancel_quest: Control

func _ready():
	hide_all_panels()
	GameInfo.set_current_panel(home_panel)
	home_panel.visible = true
	
	# Connect button signals using bind for all
	home_button.pressed.connect(handle_home_button)
	arena_button.pressed.connect(show_panel.bind(arena_panel))
	character_button.pressed.connect(show_panel.bind(character_panel))
	map_button.pressed.connect(handle_map_button)
	talents_button.pressed.connect(toggle_talents_bookmark)
	chat_button.pressed.connect(toggle_chat)
	back_button.pressed.connect(go_back)
	fight_button.pressed.connect(show_combat)
	
	# Connect cancel quest dialog buttons if they exist
	if cancel_quest:
		var yes_button = cancel_quest.get_node_or_null("DialogPanel/VBoxContainer/HBoxContainer/YesButton")
		var no_button = cancel_quest.get_node_or_null("DialogPanel/VBoxContainer/HBoxContainer/NoButton")
		var background_button = cancel_quest.get_node_or_null("BackgroundButton")
		
		if yes_button:
			yes_button.pressed.connect(_on_cancel_quest_yes)
		if no_button:
			no_button.pressed.connect(_on_cancel_quest_no)
		if background_button:
			background_button.pressed.connect(_on_cancel_quest_no)  # Close dialog when clicking background

func show_panel(panel: Control):
	hide_all_panels()
	panel.visible = true
	GameInfo.set_current_panel(panel)
	
	# Update active perks display when character panel is shown
	if panel == character_panel:
		var active_perks_display = character_panel.get_node("ActivePerks")
		if active_perks_display and active_perks_display.has_method("update_active_perks"):
			active_perks_display.update_active_perks()

func handle_home_button():
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	
	# Check quest states
	if traveling != null and destination != null:
		# Both values: traveling state - show map
		show_panel(map_panel)
		return
	elif traveling == null and destination != null:
		show_panel(quest)
		return
	
	# Normal state (both null) - standard home behavior
	# If we're already on the home panel, act like back button to exit buildings
	if GameInfo.get_current_panel() == home_panel:
		if home_panel.has_method("handle_back_navigation"):
			var handled = home_panel.handle_back_navigation()
			if handled:
				return
	
	# Otherwise, show home panel normally
	show_panel(home_panel)

func handle_map_button():
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	
	# Check quest states
	if traveling != null and destination != null:
		# Both values: traveling state - show map
		show_panel(map_panel)
		return
	elif traveling == null and destination != null:
		show_panel(quest)
		return
	
	# Normal state (both null) - standard map behavior
	show_panel(map_panel)
	
func show_panel_overlay(panel_to_toggle: Control):
	var is_active = GameInfo.get_current_panel_overlay() == panel_to_toggle and panel_to_toggle.visible
	panel_to_toggle.visible = not is_active
	GameInfo.set_current_panel_overlay(panel_to_toggle if not is_active else null)

func toggle_talents_bookmark():
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations at once
	
	if talents_panel.visible:
		# Slide out animation - panel goes right, bookmark follows
		tween.tween_property(talents_panel, "modulate:a", 0.0, 0.4)
		tween.tween_property(talents_panel, "position:x", get_viewport().get_visible_rect().size.x, 0.4)
		
		# Bookmark moves back to its original position with the panel
		var bookmark = talents_button.get_parent()
		tween.tween_property(bookmark, "offset_left", -8.0, 0.4)
		tween.tween_property(bookmark, "modulate", Color(1, 1, 1, 0.8), 0.2)
		
		tween.tween_callback(func(): 
			talents_panel.visible = false
			talents_panel.position.x = 0  # Reset position
		).set_delay(0.4)
		GameInfo.set_current_panel(character_panel)
	else:
		# Slide in animation - bookmark pulls panel from the right
		talents_panel.visible = true
		talents_panel.position.x = get_viewport().get_visible_rect().size.x
		talents_panel.modulate.a = 0.0
		
		# Bookmark extends further as it "pulls" the panel
		var bookmark = talents_button.get_parent()
		tween.tween_property(bookmark, "offset_left", 20.0, 0.4)  # Extends more during pull
		tween.tween_property(bookmark, "modulate", Color(1.2, 1.2, 1.2, 1), 0.2)  # Brighten during pull
		
		# Panel slides in from right
		tween.tween_property(talents_panel, "position:x", 0.0, 0.4)
		tween.tween_property(talents_panel, "modulate:a", 1.0, 0.4)
		
		# Bookmark returns to normal position after panel is in
		tween.tween_callback(func():
			var return_tween = create_tween()
			return_tween.tween_property(bookmark, "offset_left", -8.0, 0.2)
			return_tween.tween_property(bookmark, "modulate", Color(1, 1, 1, 1), 0.2)
		).set_delay(0.3)
		
		GameInfo.set_current_panel(talents_panel)

func toggle_chat():
	if chat_panel and chat_panel.has_method("toggle_chat"):
		chat_panel.toggle_chat()

func go_back():
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	
	# Check if quest panel is open first
	if quest and quest.visible:
		# If in quest state, show cancel dialog
		if traveling == null and destination != null:
			if cancel_quest:
				cancel_quest.visible = true
			return
		else:
			quest.visible = false
			return
		
	# Check if chat is open first
	if chat_panel and chat_panel.has_method("hide_chat") and chat_panel.get("is_chat_open"):
		chat_panel.hide_chat()
		return
		
	if GameInfo.get_current_panel_overlay() != null:
		GameInfo.get_current_panel_overlay().hide()
		GameInfo.set_current_panel_overlay(null)
		return

	# Check if we're traveling and on map panel - show cancel dialog
	if traveling != null and destination != null and GameInfo.get_current_panel() == map_panel:
		if cancel_quest:
			cancel_quest.visible = true
		return

	# Check if we're in a building interior in the home panel
	if GameInfo.get_current_panel() == home_panel:
		if home_panel.has_method("handle_back_navigation"):
			var handled = home_panel.handle_back_navigation()
			if handled:
				return

	if GameInfo.get_current_panel() == talents_panel:
		toggle_talents_bookmark()  # Use bookmark animation to slide out
	elif GameInfo.get_current_panel() == combat_panel:
		show_panel(arena_panel)
	else:
		show_panel(home_panel)



func hide_all_panels():
	home_panel.visible = false
	arena_panel.visible = false
	character_panel.visible = false
	map_panel.visible = false
	talents_panel.visible = false
	combat_panel.visible = false
	
	# Hide quest panel
	if quest:
		quest.visible = false
	
	# Hide cancel quest dialog
	if cancel_quest:
		cancel_quest.visible = false
	
	# Close chat if it's open
	if chat_panel and chat_panel.has_method("hide_chat"):
		chat_panel.hide_chat()

func show_combat():
	hide_all_panels()
	combat_panel.visible = true
	GameInfo.set_current_panel(combat_panel)

# Cancel quest dialog functions
func _on_cancel_quest_yes():
	# Cancel the quest
	GameInfo.current_player.traveling = null
	GameInfo.current_player.traveling_destination = null
	
	# Hide cancel dialog and return to home
	if cancel_quest:
		cancel_quest.visible = false
	show_panel(home_panel)
	print("Quest canceled by user")

func _on_cancel_quest_no():
	# Just hide the dialog, continue with quest
	if cancel_quest:
		cancel_quest.visible = false
