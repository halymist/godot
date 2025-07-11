extends Control

@export var home_panel: Control
@export var home_button: Button
@export var arena_panel: Control
@export var arena_button: Button
@export var character_button: Button
@export var character_panel: Control
@export var map_button: Button
@export var map_panel: Control
@export var back_button: Button

func _ready():
	hide_all_panels()
	GameInfo.set_current_panel(home_panel)
	show_panel(home_panel)
	
	# Connect button signals
	if home_button:
		home_button.pressed.connect(_on_home_button_pressed)
	if arena_button:
		arena_button.pressed.connect(_on_arena_button_pressed)
	if character_button:
		character_button.pressed.connect(_on_character_button_pressed)
	if map_button:
		map_button.pressed.connect(show_panel.bind(map_panel))
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)

# Show the specified panel and hide all others
func show_panel(panel_to_show: Control):
	if panel_to_show:
		print("show_panel called with: ", panel_to_show.name)
	
	hide_all_panels()
	panel_to_show.visible = true
	GameInfo.set_current_panel(panel_to_show)

func hide_all_panels():
	if home_panel:
		home_panel.visible = false
	if arena_panel:
		arena_panel.visible = false
	if character_panel:
		character_panel.visible = false
	if map_panel:
		map_panel.visible = false

func _on_home_button_pressed():
	show_panel(home_panel)

func _on_arena_button_pressed():
	show_panel(arena_panel)

func _on_character_button_pressed():
	show_panel(character_panel)

func _on_back_button_pressed():
	# Go back to home panel when back button is pressed
	show_panel(home_panel)
