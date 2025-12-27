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
@export var enemy: Array[Button] = []
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
	arena_button.pressed.connect(handle_arena_button)
	character_button.pressed.connect(handle_character_button)
	map_button.pressed.connect(handle_map_button)
	talents_button.pressed.connect(toggle_talents_bookmark)
	details_button.pressed.connect(toggle_details_bookmark)
	settings_button.pressed.connect(show_overlay.bind(settings_panel))
	if payment_button:
		payment_button.pressed.connect(show_overlay.bind(payment))
	if rankings_button:
		rankings_button.pressed.connect(handle_rankings_button)
	chat_button.pressed.connect(show_overlay.bind(chat_panel))
	back_button.pressed.connect(go_back)
	fight_button.pressed.connect(show_combat)
	
	# Connect avatar button if it exists
	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_button_pressed)
	
	# Connect enemy buttons to show enemy panel overlay
	for button in enemy:
		if button:
			button.pressed.connect(show_enemy_panel)
	
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
	
	print("[show_overlay] Called for: ", overlay.name)
	print("[show_overlay] Current panel before: ", GameInfo.get_current_panel().name if GameInfo.get_current_panel() else "null")
	print("[show_overlay] Current overlay before: ", GameInfo.get_current_panel_overlay().name if GameInfo.get_current_panel_overlay() else "null")
	
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
			print("[show_overlay] Showing chat overlay")
			return
	
	# For other overlays (settings/payment/enemy_panel), hide current overlay if one exists
	var current = GameInfo.get_current_panel_overlay()
	if current != null and current != overlay:
		hide_overlay(current)
	
	# Don't show if it's already the current overlay - instead hide it (toggle behavior)
	if current == overlay:
		hide_overlay(overlay)
		return
	
	# Set as current overlay in GameInfo (NOT as current panel!)
	GameInfo.set_current_panel_overlay(overlay)
	print("[show_overlay] Set as current overlay: ", overlay.name)
	
	# Ensure overlay has high z-index to appear above everything (including utility panels at z=100)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	print("[show_overlay] Set overlay z_index=200 and mouse_filter=STOP for: ", overlay.name)
	
	# Call the overlay's specific show method based on its type
	# IMPORTANT: These methods should NOT call GameInfo.set_current_panel()
	if overlay == quest_panel and overlay.has_method("show_quest"):
		# Note: show_quest should already have been called with data, just make visible
		overlay.visible = true
	elif overlay == enemy_panel:
		# Enemy panel is an overlay - use simple visibility, don't call show_panel()
		print("[show_overlay] Using simple visibility for enemy panel (overlay)")
		overlay.visible = true
	elif overlay.has_method("show_overlay"):
		print("[show_overlay] Calling show_overlay() method on: ", overlay.name)
		overlay.show_overlay()
	elif overlay.has_method("show_panel"):
		print("[show_overlay] Calling show_panel() method on: ", overlay.name)
		overlay.show_panel()
	else:
		# Fallback to simple visibility
		print("[show_overlay] Using simple visibility for: ", overlay.name)
		overlay.visible = true
	
	print("[show_overlay] Current panel after: ", GameInfo.get_current_panel().name if GameInfo.get_current_panel() else "null")
	print("[show_overlay] Current overlay after: ", GameInfo.get_current_panel_overlay().name if GameInfo.get_current_panel_overlay() else "null")

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
	if current_utility_panel:
		hide_utility_panel(current_utility_panel)
	current_utility_panel = null
	chat_overlay_active = false
	
	# Clear any active overlay
	var current_overlay = GameInfo.get_current_panel_overlay()
	if current_overlay:
		hide_overlay(current_overlay)
	
	# Hide all utility panels
	if vendor_panel:
		vendor_panel.visible = false
	if blacksmith_panel:
		blacksmith_panel.visible = false
	if trainer_panel:
		trainer_panel.visible = false
	if church_panel:
		church_panel.visible = false
	if alchemist_panel:
		alchemist_panel.visible = false
	if enchanter_panel:
		enchanter_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	if payment:
		payment.visible = false
	
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
	# Hide utility panels when going home
	if current_utility_panel:
		hide_utility_panel(current_utility_panel)
	
	if vendor_panel:
		vendor_panel.visible = false
	if blacksmith_panel:
		blacksmith_panel.visible = false
	if trainer_panel:
		trainer_panel.visible = false
	if church_panel:
		church_panel.visible = false
	if alchemist_panel:
		alchemist_panel.visible = false
	if enchanter_panel:
		enchanter_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	if payment:
		payment.visible = false
	
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
	
	# Check if already on map panel - toggle off (go home)
	var current = GameInfo.get_current_panel()
	if current == map_panel:
		print("[Map Button] Already on map, going home")
		show_panel(home_panel)
		return
	
	# Check quest states
	if traveling > 0 and destination != null:
		# Both values: traveling state - show map
		print("[Map Button] Traveling state - showing map")
		show_panel(map_panel)
		return
	elif traveling == null and destination != null:
		print("[Map Button] Quest available - showing quest")
		show_panel(quest)
		return
	
	# Normal state (both null) - standard map behavior
	print("[Map Button] Normal state - showing map")
	show_panel(map_panel)

func handle_arena_button():
	"""Toggle arena panel - show if not active, go home if already active"""
	if GameInfo.get_current_panel() == arena_panel:
		show_panel(home_panel)
	else:
		show_panel(arena_panel)

func handle_character_button():
	"""Toggle character panel - show if not active, go home if already active"""
	if GameInfo.get_current_panel() == character_panel:
		show_panel(home_panel)
	else:
		show_panel(character_panel)

func handle_rankings_button():
	"""Toggle rankings panel - show if not active, go home if already active"""
	if GameInfo.get_current_panel() == rankings_panel:
		show_panel(home_panel)
	else:
		show_panel(rankings_panel)
	
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

func show_enemy_panel():
	"""Show enemy panel as overlay on top of rankings panel"""
	if enemy_panel:
		show_overlay(enemy_panel)

func _on_avatar_button_pressed():
	"""Show avatar panel as overlay on top of character panel"""
	if avatar_panel:
		show_overlay(avatar_panel)

func toggle_talents_bookmark():
	if talents_panel.visible:
		talents_panel.visible = false
		GameInfo.set_current_panel(character_panel)
	else:
		talents_panel.visible = true
		GameInfo.set_current_panel(talents_panel)

func toggle_details_bookmark():
	if details_panel.visible:
		details_panel.visible = false
		GameInfo.set_current_panel(character_panel)
	else:
		details_panel.visible = true
		GameInfo.set_current_panel(details_panel)


func go_back():
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	var current = GameInfo.get_current_panel()
	
	print("[go_back] Back button pressed")
	print("[go_back] Current panel: ", current.name if current else "null")
	print("[go_back] Chat overlay active: ", chat_overlay_active)
	
	# Priority 1: Check if chat is visible (top priority - chat overlay)
	if chat_overlay_active and chat_panel and chat_panel.visible:
		print("[go_back] Priority 1: Hiding chat overlay")
		hide_overlay(chat_panel)
		return
	
	# Priority 2: Hide any other active overlay (settings/payment/enemy_panel)
	var current_overlay = GameInfo.get_current_panel_overlay()
	print("[go_back] Current overlay: ", current_overlay.name if current_overlay else "null")
	if current_overlay != null and current_overlay.visible:
		print("[go_back] Priority 2: Hiding overlay: ", current_overlay.name)
		hide_overlay(current_overlay)
		return
	
	# Priority 3: Utility panel (blacksmith, vendor, etc.) - middle priority
	print("[go_back] Current utility panel: ", current_utility_panel.name if current_utility_panel else "null")
	if current_utility_panel and current_utility_panel.visible:
		print("[go_back] Priority 3: Hiding utility panel")
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

	# Priority 6: Check if we're in a building interior in the home panel
	if current == home_panel:
		if home_panel.has_method("handle_back_navigation"):
			var handled = home_panel.handle_back_navigation()
			if handled:
				return

	# Priority 7: Handle panel-specific back navigation
	if current == talents_panel:
		toggle_talents_bookmark()
	elif current == details_panel:
		toggle_details_bookmark()
	elif current == combat_panel:
		show_panel(arena_panel)
	else:
		show_panel(home_panel)



func show_utility_panel(panel: Control):
	"""Show a utility panel (blacksmith, vendor, etc.) and track it as overlay"""
	if panel:
		print("[TogglePanel] show_utility_panel called for: ", panel.name)
		# Hide any currently active overlay first
		var current_overlay = GameInfo.get_current_panel_overlay()
		if current_overlay != null and current_overlay != panel:
			hide_overlay(current_overlay)
		
		current_utility_panel = panel
		panel.visible = true
		# Track as current overlay in GameInfo
		GameInfo.set_current_panel_overlay(panel)

func hide_utility_panel(panel: Control):
	"""Hide a utility panel and clear tracking"""
	if panel:
		current_utility_panel = null
		panel.visible = false
		# Clear from GameInfo overlay tracking
		if GameInfo.get_current_panel_overlay() == panel:
			GameInfo.set_current_panel_overlay(null)

func hide_all_panels():
	home_panel.visible = false
	arena_panel.visible = false
	character_panel.visible = false
	map_panel.visible = false
	talents_panel.visible = false
	details_panel.visible = false
	combat_panel.visible = false
	quest.visible = false
	if rankings_panel:
		rankings_panel.visible = false
	
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
