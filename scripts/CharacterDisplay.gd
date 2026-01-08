extends Control
class_name CharacterDisplay

# Button references
@export var talents_button: Button
@export var details_button: Button
@export var avatar_button: Button

func _ready():
	# Connect button signals
	if talents_button:
		talents_button.pressed.connect(_on_talents_pressed)
	if details_button:
		details_button.pressed.connect(_on_details_pressed)
	if avatar_button:
		avatar_button.pressed.connect(_on_avatar_pressed)

func _on_talents_pressed():
	if UIManager.instance:
		UIManager.instance.toggle_talents_bookmark()

func _on_details_pressed():
	if UIManager.instance:
		UIManager.instance.toggle_details_bookmark()

func _on_avatar_pressed():
	if UIManager.instance:
		UIManager.instance.toggle_avatar_overlay()
