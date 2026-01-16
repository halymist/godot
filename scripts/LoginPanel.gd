extends Control

# Login panel for authentication
@export var lobby_panel: Control

# Login method buttons
@export var email_button: Button
@export var facebook_button: Button
@export var google_button: Button
@export var steam_button: Button

# Login sections (one for each method)
@export var email_section: Control
@export var facebook_section: Control
@export var google_section: Control
@export var steam_section: Control

# Login action buttons
@export var email_login_button: Button
@export var facebook_login_button: Button
@export var google_login_button: Button
@export var steam_login_button: Button

func _ready():
	# Connect method selection buttons
	email_button.pressed.connect(_on_method_selected.bind("email"))
	facebook_button.pressed.connect(_on_method_selected.bind("facebook"))
	google_button.pressed.connect(_on_method_selected.bind("google"))
	steam_button.pressed.connect(_on_method_selected.bind("steam"))
	
	# Connect login buttons
	email_login_button.pressed.connect(_on_login)
	facebook_login_button.pressed.connect(_on_login)
	google_login_button.pressed.connect(_on_login)
	steam_login_button.pressed.connect(_on_login)
	
	# Start with email selected
	_on_method_selected("email")

func _on_method_selected(method: String):
	"""Show the selected login method section"""
	email_section.visible = method == "email"
	facebook_section.visible = method == "facebook"
	google_section.visible = method == "google"
	steam_section.visible = method == "steam"

func _on_login():
	"""Handle login (accept everything for now)"""
	visible = false
	lobby_panel.visible = true
