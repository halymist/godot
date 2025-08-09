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

func _ready():
	hide_all_panels()
	GameInfo.set_current_panel(home_panel)
	home_panel.visible = true
	
	# Connect button signals using bind for all
	home_button.pressed.connect(show_panel.bind(home_panel))
	arena_button.pressed.connect(show_panel.bind(arena_panel))
	character_button.pressed.connect(show_panel.bind(character_panel))
	map_button.pressed.connect(show_panel.bind(map_panel))
	talents_button.pressed.connect(toggle_talents_bookmark)
	chat_button.pressed.connect(toggle_chat)
	back_button.pressed.connect(go_back)
	fight_button.pressed.connect(show_combat)

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

func toggle_talents_bookmark():
	var tween = create_tween()
	
	if talents_panel.visible:
		# Slide out animation
		tween.tween_property(talents_panel, "modulate:a", 0.0, 0.3)
		tween.tween_property(talents_panel, "position:x", get_viewport().get_visible_rect().size.x, 0.3)
		tween.tween_callback(func(): talents_panel.visible = false)
		GameInfo.set_current_panel(character_panel)
	else:
		# Slide in animation
		talents_panel.visible = true
		talents_panel.position.x = get_viewport().get_visible_rect().size.x
		talents_panel.modulate.a = 0.0
		
		tween.tween_property(talents_panel, "position:x", 0.0, 0.3)
		tween.tween_property(talents_panel, "modulate:a", 1.0, 0.3)
		GameInfo.set_current_panel(talents_panel)

func toggle_chat():
	if chat_panel and chat_panel.has_method("toggle_chat"):
		chat_panel.toggle_chat()

func go_back():
	# Check if chat is open first
	if chat_panel and chat_panel.has_method("hide_chat") and chat_panel.get("is_chat_open"):
		chat_panel.hide_chat()
		return
		
	if GameInfo.get_current_panel_overlay() != null:
		GameInfo.get_current_panel_overlay().hide()
		GameInfo.set_current_panel_overlay(null)
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
	
	# Close chat if it's open
	if chat_panel and chat_panel.has_method("hide_chat"):
		chat_panel.hide_chat()

func show_combat():
	hide_all_panels()
	combat_panel.visible = true
	GameInfo.set_current_panel(combat_panel)
