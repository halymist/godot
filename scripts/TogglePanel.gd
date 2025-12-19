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
@export var settings_button: Button
@export var rankings_button: Button
@export var chat_button: Button
@export var chat_panel: Control
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
@export var payment: Control
@export var payment_button: Button
@export var avatar_panel: Control
@export var avatar_button: Button

# Wide mode buttons
@export_group("Wide Buttons")
@export var wide_home_button: Button
@export var wide_arena_button: Button
@export var wide_settings_button: Button
@export var wide_chat_button: Button
@export var wide_map_button: Button
@export var wide_character_button: Button
@export var wide_rankings_button: Button
@export var wide_payment_button: Button
@export var wide_back_button: Button

# Track three levels of UI
var current_utility_panel: Control = null  # Blacksmith, Vendor, Enchanter, etc.
var chat_overlay_active: bool = false  # Chat is always top priority


func _ready():
	
	hide_all_panels()
	GameInfo.set_current_panel(home_panel)
	home_panel.visible = true
	
	# Connect button signals using bind for all
	home_button.pressed.connect(handle_home_button)
	arena_button.pressed.connect(show_panel.bind(arena_panel))
	character_button.pressed.connect(show_overlay.bind(character_panel))
	map_button.pressed.connect(handle_map_button)
	talents_button.pressed.connect(toggle_talents_bookmark)
	settings_button.pressed.connect(show_overlay.bind(settings_panel))
	if payment_button:
		payment_button.pressed.connect(show_overlay.bind(payment))
	if rankings_button:
		rankings_button.pressed.connect(show_overlay.bind(rankings_panel))
	chat_button.pressed.connect(show_overlay.bind(chat_panel))
	back_button.pressed.connect(go_back)
	fight_button.pressed.connect(show_combat)
	
	# Connect Wide button signals to same handlers
	if wide_home_button:
		wide_home_button.pressed.connect(handle_home_button)
	if wide_arena_button:
		wide_arena_button.pressed.connect(show_panel.bind(arena_panel))
	if wide_settings_button:
		wide_settings_button.pressed.connect(show_overlay.bind(settings_panel))
	if wide_chat_button:
		wide_chat_button.pressed.connect(show_overlay.bind(chat_panel))
	if wide_map_button:
		wide_map_button.pressed.connect(handle_map_button)
	if wide_character_button:
		wide_character_button.pressed.connect(show_overlay.bind(character_panel))
	if wide_rankings_button:
		wide_rankings_button.pressed.connect(show_overlay.bind(rankings_panel))
	if wide_payment_button:
		wide_payment_button.pressed.connect(show_overlay.bind(payment))
	if wide_back_button:
		wide_back_button.pressed.connect(go_back)
	
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

func show_overlay(overlay: Control):
	"""Unified overlay function - hides current overlay and shows the new one"""
	if overlay == null:
		return
	
	# Chat is special - it can show over everything but should toggle off if already active
	if overlay == chat_panel:
		if chat_overlay_active:
			# Chat is already active, toggle it off
			hide_overlay(chat_panel)
			return
		else:
			# Show chat overlay
			chat_overlay_active = true
			if overlay.has_method("show_chat"):
				overlay.show_chat()
			else:
				overlay.visible = true
			print("Showing chat overlay")
			return
	
	# For other overlays (settings/rankings/payment), hide current overlay if one exists
	var current = GameInfo.get_current_panel_overlay()
	if current != null and current != overlay:
		hide_overlay(current)
	
	# Don't show if it's already the current overlay - instead hide it (toggle behavior)
	if current == overlay:
		hide_overlay(overlay)
		return
	
	# Set as current overlay in GameInfo
	GameInfo.set_current_panel_overlay(overlay)
	
	# Call the overlay's specific show method based on its type
	if overlay == quest_panel and overlay.has_method("show_quest"):
		# Note: show_quest should already have been called with data, just make visible
		overlay.visible = true
	elif overlay.has_method("show_overlay"):
		overlay.show_overlay()
	elif overlay.has_method("show_panel"):
		overlay.show_panel()
	else:
		# Fallback to simple visibility
		overlay.visible = true
	
	print("Showing overlay: ", overlay.name)

func hide_overlay(overlay: Control):
	"""Hide a specific overlay using its own hide method"""
	if overlay == null:
		return
	
	# Track chat state
	if overlay == chat_panel:
		chat_overlay_active = false
	
	# Clear from GameInfo if it's the current overlay
	if GameInfo.get_current_panel_overlay() == overlay:
		GameInfo.set_current_panel_overlay(null)
	
	# Call the overlay's specific hide method based on its type
	if overlay == chat_panel and overlay.has_method("hide_chat"):
		overlay.hide_chat()
	elif overlay == quest_panel and overlay.has_method("hide_panel"):
		overlay.hide_panel()
	elif overlay.has_method("hide_overlay"):
		overlay.hide_overlay()
	elif overlay.has_method("hide_panel"):
		overlay.hide_panel()
	else:
		# Fallback to simple visibility
		overlay.visible = false
	
	print("Hiding overlay: ", overlay.name)

func show_panel(panel: Control):
	hide_all_panels()
	
	# Clear utility panel and chat tracking when switching main panels
	current_utility_panel = null
	chat_overlay_active = false
	
	# Also hide utility panel wrappers
	if vendor_panel:
		var vendor_wrapper = vendor_panel.get_parent()
		if vendor_wrapper:
			vendor_wrapper.visible = false
	if blacksmith_panel:
		var blacksmith_wrapper = blacksmith_panel.get_parent()
		if blacksmith_wrapper:
			blacksmith_wrapper.visible = false
	if trainer_panel:
		var trainer_wrapper = trainer_panel.get_parent()
		if trainer_wrapper:
			trainer_wrapper.visible = false
	if church_panel:
		var church_wrapper = church_panel.get_parent()
		if church_wrapper:
			church_wrapper.visible = false
	if alchemist_panel:
		var alchemist_wrapper = alchemist_panel.get_parent()
		if alchemist_wrapper:
			alchemist_wrapper.visible = false
	if enchanter_panel:
		var enchanter_wrapper = enchanter_panel.get_parent()
		if enchanter_wrapper:
			enchanter_wrapper.visible = false
	if settings_panel:
		settings_panel.visible = false
	if rankings_panel:
		rankings_panel.visible = false
	if payment:
		payment.visible = false
	# Hide enemy panel when switching to other panels
	if enemy_panel:
		enemy_panel.visible = false
	
	# If switching away from home panel, ensure we're back to village outside view
	if GameInfo.get_current_panel() == home_panel and panel != home_panel:
		if home_panel.has_method("handle_back_navigation"):
			home_panel.handle_back_navigation()
	
	panel.visible = true
	GameInfo.set_current_panel(panel)
	
	# Update active perks display when character panel is shown
	if panel == character_panel:
		var active_perks_display = character_panel.get_node("ActivePerksBackground/ActivePerks")
		if active_perks_display and active_perks_display.has_method("update_active_perks"):
			active_perks_display.update_active_perks()

func handle_home_button():
	# Hide utility panel wrappers when going home
	if vendor_panel:
		var vendor_wrapper = vendor_panel.get_parent()
		if vendor_wrapper:
			vendor_wrapper.visible = false
	if blacksmith_panel:
		var blacksmith_wrapper = blacksmith_panel.get_parent()
		if blacksmith_wrapper:
			blacksmith_wrapper.visible = false
	if trainer_panel:
		var trainer_wrapper = trainer_panel.get_parent()
		if trainer_wrapper:
			trainer_wrapper.visible = false
	if church_panel:
		var church_wrapper = church_panel.get_parent()
		if church_wrapper:
			church_wrapper.visible = false
	if alchemist_panel:
		var alchemist_wrapper = alchemist_panel.get_parent()
		if alchemist_wrapper:
			alchemist_wrapper.visible = false
	if enchanter_panel:
		var enchanter_wrapper = enchanter_panel.get_parent()
		if enchanter_wrapper:
			enchanter_wrapper.visible = false
	if settings_panel:
		settings_panel.visible = false
	if rankings_panel:
		rankings_panel.visible = false
	if payment:
		payment.visible = false
	# Hide enemy panel when going home
	if enemy_panel:
		enemy_panel.visible = false
	
	# If we're in an interior, exit to village
	if home_panel.has_method("handle_back_navigation"):
		home_panel.handle_back_navigation()
	
	# Center the village view
	if home_panel.has_method("center_village_view"):
		home_panel.center_village_view()
	
	# Show home panel
	show_panel(home_panel)

func handle_map_button():
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	print("Traveling: ", traveling, " Destination: ", destination)
	
	# Check quest states
	if traveling > 0 and destination != null:
		# Both values: traveling state - show map
		show_panel(map_panel)
		return
	elif traveling == null and destination != null:
		show_panel(quest)
		return
	
	# Normal state (both null) - standard map behavior
	show_panel(map_panel)
	
func show_panel_overlay(panel_to_toggle: Control):
	"""Legacy function - now uses the unified show_overlay function"""
	show_overlay(panel_to_toggle)

# Convenience methods for specific overlays
func show_quest_panel():
	show_overlay(quest_panel)

func show_cancel_quest():
	show_overlay(cancel_quest)

func show_chat():
	show_overlay(chat_panel)

func show_upgrade_talent():
	show_overlay(upgrade_talent)

func show_perks_panel():
	show_overlay(perks_panel)

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


func go_back():
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	var current = GameInfo.get_current_panel()
	
	# Priority 1: Check if chat is visible (top priority - chat overlay)
	if chat_overlay_active and chat_panel and chat_panel.visible:
		hide_overlay(chat_panel)
		return
	
	# Priority 2: Hide any other active overlay (settings/rankings/payment)
	var current_overlay = GameInfo.get_current_panel_overlay()
	if current_overlay != null and current_overlay.visible:
		hide_overlay(current_overlay)
		return
	
	# Priority 3: Utility panel (blacksmith, vendor, etc.) - middle priority
	if current_utility_panel and current_utility_panel.visible:
		hide_utility_panel(current_utility_panel)
		return
	
	# Priority 4: Check if we're traveling and on map panel - show cancel dialog
	if traveling > 0 and destination != null and current == map_panel:
		show_overlay(cancel_quest)
		return
	
	# Priority 5: Check if we've arrived at quest (traveling = 0) but haven't finished it yet - show cancel dialog
	if traveling == 0 and destination != null and current == quest:
		show_overlay(cancel_quest)
		return

	# Priority 6: Check if current panel is enemy_panel - toggle it off
	if enemy_panel != null and current == enemy_panel:
		enemy_panel.visible = false
		GameInfo.set_current_panel(rankings_panel)
		return

	# Priority 7: Check if we're in a building interior in the home panel
	if current == home_panel:
		if home_panel.has_method("handle_back_navigation"):
			var handled = home_panel.handle_back_navigation()
			if handled:
				return

	# Priority 8: Handle panel-specific back navigation
	if current == talents_panel:
		toggle_talents_bookmark()  # Use bookmark animation to slide out
	elif current == combat_panel:
		show_panel(arena_panel)
	else:
		show_panel(home_panel)



func show_utility_panel(panel: Control):
	"""Show a utility panel (blacksmith, vendor, etc.) and track it"""
	if panel:
		current_utility_panel = panel
		panel.visible = true
		# Also make the wrapper visible if it exists
		var wrapper = panel.get_parent()
		if wrapper:
			wrapper.visible = true

func hide_utility_panel(panel: Control):
	"""Hide a utility panel and clear tracking"""
	if panel:
		current_utility_panel = null
		panel.visible = false
		# Also hide the wrapper if it exists
		var wrapper = panel.get_parent()
		if wrapper:
			wrapper.visible = false

func hide_all_panels():
	home_panel.visible = false
	arena_panel.visible = false
	character_panel.visible = false
	map_panel.visible = false
	talents_panel.visible = false
	combat_panel.visible = false
	quest.visible = false
	
	# Hide any active overlay using GameInfo system
	var current_overlay = GameInfo.get_current_panel_overlay()
	if current_overlay != null:
		hide_overlay(current_overlay)

func show_combat():
	hide_all_panels()
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
