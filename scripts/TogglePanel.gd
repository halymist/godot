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

func _ready():
	hide_all_panels()
	GameInfo.set_current_panel(home_panel)
	home_panel.visible = true
	
	# Connect button signals using bind for all
	home_button.pressed.connect(show_panel.bind(home_panel))
	arena_button.pressed.connect(show_panel.bind(arena_panel))
	character_button.pressed.connect(show_panel.bind(character_panel))
	map_button.pressed.connect(show_panel.bind(map_panel))
	talents_button.pressed.connect(show_panel.bind(talents_panel))
	chat_button.pressed.connect(show_panel_overlay.bind(chat_panel))
	back_button.pressed.connect(go_back)

func show_panel(panel: Control):
	hide_all_panels()
	panel.visible = true
	GameInfo.set_current_panel(panel)
	
	# Update active perks display when character panel is shown
	if panel == character_panel:
		var active_perks_display = character_panel.get_node("ActivePerks")
		if active_perks_display and active_perks_display.has_method("update_active_perks"):
			active_perks_display.update_active_perks()
	
func show_panel_overlay(panel_to_toggle: Control):
	var is_active = GameInfo.get_current_panel_overlay() == panel_to_toggle and panel_to_toggle.visible
	panel_to_toggle.visible = not is_active
	GameInfo.set_current_panel_overlay(panel_to_toggle if not is_active else null)

func go_back():
	if GameInfo.get_current_panel_overlay() != null:
		GameInfo.get_current_panel_overlay().hide()
		GameInfo.set_current_panel_overlay(null)
		return

	if GameInfo.get_current_panel() == talents_panel:
		show_panel(character_panel)
	else:
		show_panel(home_panel)



func hide_all_panels():
	home_panel.visible = false
	arena_panel.visible = false
	character_panel.visible = false
	map_panel.visible = false
	talents_panel.visible = false
	chat_panel.visible = false
