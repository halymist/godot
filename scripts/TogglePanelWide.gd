extends Control

# Export references to panels
@export var home_panel: Control
@export var character_panel: Control
@export var settings_panel: Control
@export var payment_panel: Control
@export var arena_panel: Control
@export var map_panel: Control
@export var rankings_panel: Control
@export var chat_panel: Control

# List of all utility panels (non-toggle panels that should close when switching views)
var utility_panels: Array = []

func _ready():
	# Initially show only home panel
	if home_panel:
		home_panel.visible = true
	
	# Hide all other panels
	_hide_all_panels_except(home_panel)

func _hide_all_panels_except(except_panel: Control):
	"""Hide all panels except the specified one"""
	var panels = [home_panel, character_panel, settings_panel, payment_panel, 
	              arena_panel, map_panel, rankings_panel, chat_panel]
	
	for panel in panels:
		if panel and panel != except_panel:
			panel.visible = false
	
	# Also hide all utility panels
	for util_panel in utility_panels:
		if util_panel:
			util_panel.visible = false

func _on_home_button_pressed():
	_hide_all_panels_except(home_panel)
	if home_panel:
		home_panel.visible = true

func _on_arena_button_pressed():
	_hide_all_panels_except(arena_panel)
	if arena_panel:
		arena_panel.visible = true

func _on_map_button_pressed():
	_hide_all_panels_except(map_panel)
	if map_panel:
		map_panel.visible = true

func _on_rankings_button_pressed():
	_hide_all_panels_except(rankings_panel)
	if rankings_panel:
		rankings_panel.visible = true

func _on_chat_button_pressed():
	_hide_all_panels_except(chat_panel)
	if chat_panel:
		chat_panel.visible = true

func _on_settings_button_pressed():
	_hide_all_panels_except(settings_panel)
	if settings_panel:
		settings_panel.visible = true

func _on_payment_button_pressed():
	# Payment is a popup, don't hide other panels
	if payment_panel:
		payment_panel.visible = !payment_panel.visible
