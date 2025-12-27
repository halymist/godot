extends Control

# Wide mode toggle panel - handles dual-panel display
# Shares state with portrait via GameInfo

# Main panels
@export var home_panel: Control
@export var character_panel: Control
@export var arena_panel: Control
@export var map_panel: Control

# Companion panels (shown alongside main panels)
@export var talents_panel: Control
@export var enemy_panel: Control
@export var details_panel: Control

# Overlay panels
@export var settings_panel: Control
@export var rankings_panel: Control
@export var payment: Control
@export var chat_panel: Control

# Utility panels
@export var vendor_panel: Control
@export var blacksmith_panel: Control
@export var trainer_panel: Control
@export var church_panel: Control
@export var alchemist_panel: Control
@export var enchanter_panel: Control

# Wide buttons
@export_group("Wide Buttons")
@export var wide_home_button: Button
@export var wide_character_button: Button
@export var wide_arena_button: Button
@export var wide_map_button: Button
@export var wide_settings_button: Button
@export var wide_rankings_button: Button
@export var wide_payment_button: Button
@export var wide_chat_button: Button
@export var wide_back_button: Button

# Track utility panel
var current_utility_panel: Control = null
var chat_overlay_active: bool = false

func _ready():
	# Connect wide button signals
	if wide_home_button:
		wide_home_button.pressed.connect(handle_home_button)
	if wide_character_button:
		wide_character_button.pressed.connect(handle_character_button)
	if wide_arena_button:
		wide_arena_button.pressed.connect(handle_arena_button)
	if wide_map_button:
		wide_map_button.pressed.connect(handle_map_button)
	if wide_settings_button:
		wide_settings_button.pressed.connect(show_overlay.bind(settings_panel))
	if wide_rankings_button:
		wide_rankings_button.pressed.connect(show_overlay.bind(rankings_panel))
	if wide_payment_button:
		wide_payment_button.pressed.connect(show_overlay.bind(payment))
	if wide_chat_button:
		wide_chat_button.pressed.connect(show_overlay.bind(chat_panel))
	if wide_back_button:
		wide_back_button.pressed.connect(go_back)

func handle_home_button():
	show_panel(home_panel)

func handle_quest_completed():
	"""Called when quest is finished - return to home"""
	# Note: Wide mode may not have quest panel exported, handled by portrait
	
	# Use show_panel to properly toggle everything
	show_panel(home_panel)

func handle_character_button():
	"""Character (left) + Talents (right)"""
	if GameInfo.get_current_panel() == character_panel:
		show_panel(home_panel)
	else:
		show_panel(character_panel)

func handle_arena_button():
	if GameInfo.get_current_panel() == arena_panel:
		show_panel(home_panel)
	else:
		show_panel(arena_panel)

func handle_map_button():
	if GameInfo.get_current_panel() == map_panel:
		show_panel(home_panel)
	else:
		show_panel(map_panel)

func show_panel(panel: Control):
	"""Show main panel with its companion in wide mode"""
	hide_all_panels()
	
	# Clear utility panels and overlays
	if current_utility_panel:
		hide_utility_panel(current_utility_panel)
	current_utility_panel = null
	chat_overlay_active = false
	
	var current_overlay = GameInfo.get_current_panel_overlay()
	if current_overlay:
		hide_overlay(current_overlay)
	
	# Show main panel + companion based on which panel it is
	if panel == character_panel:
		# Character (left) + Talents (right)
		character_panel.visible = true
		if talents_panel:
			talents_panel.visible = true
		if details_panel:
			details_panel.visible = true
		print("Wide: Showing Character (left) + Talents + Details (right)")
	else:
		# Other panels show in full container
		panel.visible = true
		print("Wide: Showing ", panel.name, " (full)")
	
	GameInfo.set_current_panel(panel)

func show_overlay(overlay: Control):
	"""Show overlay panel, with companion if applicable"""
	if overlay == null:
		return
	
	# Chat is special - toggle behavior
	if overlay == chat_panel:
		if chat_overlay_active:
			hide_overlay(chat_panel)
			return
		else:
			chat_overlay_active = true
			overlay.visible = true
			print("Wide: Showing chat overlay")
			return
	
	# For other overlays, hide current and show new
	var current = GameInfo.get_current_panel_overlay()
	if current != null and current != overlay:
		hide_overlay(current)
	
	# Toggle behavior - if already showing, hide it
	if current == overlay:
		hide_overlay(overlay)
		return
	
	GameInfo.set_current_panel_overlay(overlay)
	
	# Show overlay with companion if applicable
	if overlay == rankings_panel:
		# Rankings (left) + Enemy (right)
		overlay.visible = true
		if enemy_panel:
			enemy_panel.visible = true
		print("Wide: Showing Rankings (left) + Enemy (right)")
	else:
		# Other overlays just show normally
		overlay.visible = true
		print("Wide: Showing overlay ", overlay.name)

func hide_overlay(overlay: Control):
	"""Hide overlay and its companion"""
	if overlay == null:
		return
	
	if overlay == chat_panel:
		chat_overlay_active = false
	
	if GameInfo.get_current_panel_overlay() == overlay:
		GameInfo.set_current_panel_overlay(null)
	
	overlay.visible = false
	
	# Hide companions
	if overlay == rankings_panel and enemy_panel:
		enemy_panel.visible = false
	
	print("Wide: Hiding overlay ", overlay.name)

func show_utility_panel(panel: Control):
	"""Show utility panel (blacksmith, vendor, etc.)"""
	if panel:
		var current_overlay = GameInfo.get_current_panel_overlay()
		if current_overlay != null and current_overlay != panel:
			hide_overlay(current_overlay)
		
		current_utility_panel = panel
		panel.visible = true
		GameInfo.set_current_panel_overlay(panel)

func hide_utility_panel(panel: Control):
	"""Hide utility panel"""
	if panel:
		current_utility_panel = null
		panel.visible = false
		if GameInfo.get_current_panel_overlay() == panel:
			GameInfo.set_current_panel_overlay(null)

func hide_all_panels():
	"""Hide all main panels and companions"""
	if home_panel:
		home_panel.visible = false
	if character_panel:
		character_panel.visible = false
	if arena_panel:
		arena_panel.visible = false
	if map_panel:
		map_panel.visible = false
	if talents_panel:
		talents_panel.visible = false
	if details_panel:
		details_panel.visible = false
	if enemy_panel:
		enemy_panel.visible = false
	
	# Hide overlays
	if settings_panel:
		settings_panel.visible = false
	if rankings_panel:
		rankings_panel.visible = false
	if payment:
		payment.visible = false
	
	# Hide utilities
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

func go_back():
	"""Handle back button in wide mode"""
	# Priority 1: Chat overlay
	if chat_overlay_active and chat_panel and chat_panel.visible:
		hide_overlay(chat_panel)
		return
	
	# Priority 2: Other overlays
	var current_overlay = GameInfo.get_current_panel_overlay()
	if current_overlay != null and current_overlay.visible:
		hide_overlay(current_overlay)
		return
	
	# Priority 3: Utility panels
	if current_utility_panel and current_utility_panel.visible:
		hide_utility_panel(current_utility_panel)
		return
	
	# Priority 4: Go to home
	show_panel(home_panel)
