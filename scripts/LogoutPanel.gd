extends Control

@export var yes_button: Button
@export var no_button: Button
@export var background_button: Button

func _ready():
	# Get buttons if not assigned via export
	if not yes_button:
		yes_button = get_node("DialogPanel/VBoxContainer/HBoxContainer/YesButton")
	if not no_button:
		no_button = get_node("DialogPanel/VBoxContainer/HBoxContainer/NoButton")
	if not background_button:
		background_button = get_node("BackgroundButton")
	
	# Connect button signals
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	background_button.pressed.connect(_on_no_pressed)

func _on_yes_pressed():
	"""Handle logout confirmation - save player and return to lobby"""
	print("Logging out - saving player and returning to lobby")
	
	# Save current player data back to all_characters array
	if GameInfo.current_player and GameInfo.current_character_id >= 0:
		GameInfo.save_current_character()
		print("Saved character ID: ", GameInfo.current_character_id)
	
	# Clear current player
	GameInfo.current_player = null
	GameInfo.current_character_id = -1
	
	# Call UIManager to handle UI transition
	if UIManager.instance:
		UIManager.instance.handle_logout()

func _on_no_pressed():
	"""Handle logout cancel - just hide the dialog"""
	if UIManager.instance:
		UIManager.instance.hide_current_overlay()
