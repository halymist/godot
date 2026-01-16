extends Control

# Login panel for authentication
@export var lobby_panel: Control

# Mode toggle buttons
@export var login_mode_button: Button
@export var register_mode_button: Button

# Login method buttons
@export var email_button: Button
@export var facebook_button: Button
@export var google_button: Button
@export var steam_button: Button

# Login sections
@export var email_login_section: Control
@export var facebook_login_section: Control
@export var google_login_section: Control
@export var steam_login_section: Control

# Register sections
@export var email_register_section: Control
@export var facebook_register_section: Control
@export var google_register_section: Control
@export var steam_register_section: Control

# Login action buttons
@export var email_login_button: Button
@export var facebook_login_button: Button
@export var google_login_button: Button
@export var steam_login_button: Button

# Register action buttons
@export var email_register_button: Button
@export var facebook_register_button: Button
@export var google_register_button: Button
@export var steam_register_button: Button

var current_method: String = "email"
var is_register_mode: bool = false

func _ready():
	# Connect mode toggle buttons
	login_mode_button.pressed.connect(_on_mode_toggle.bind(false))
	register_mode_button.pressed.connect(_on_mode_toggle.bind(true))
	
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
	
	# Connect register buttons
	email_register_button.pressed.connect(_on_register)
	facebook_register_button.pressed.connect(_on_register)
	google_register_button.pressed.connect(_on_register)
	steam_register_button.pressed.connect(_on_register)
	
	# Start with login mode and email selected
	_on_mode_toggle(false)
	_on_method_selected("email")

func _on_mode_toggle(register: bool):
	"""Toggle between login and register mode"""
	is_register_mode = register
	_update_ui_for_mode()

func _update_ui_for_mode():
	"""Update UI to show login or register sections"""
	if is_register_mode:
		# Show register sections
		email_register_section.visible = current_method == "email"
		facebook_register_section.visible = current_method == "facebook"
		google_register_section.visible = current_method == "google"
		steam_register_section.visible = current_method == "steam"
		# Hide login sections
		email_login_section.visible = false
		facebook_login_section.visible = false
		google_login_section.visible = false
		steam_login_section.visible = false
	else:
		# Show login sections
		email_login_section.visible = current_method == "email"
		facebook_login_section.visible = current_method == "facebook"
		google_login_section.visible = current_method == "google"
		steam_login_section.visible = current_method == "steam"
		# Hide register sections
		email_register_section.visible = false
		facebook_register_section.visible = false
		google_register_section.visible = false
		steam_register_section.visible = false

func _on_method_selected(method: String):
	"""Show the selected login method section"""
	current_method = method
	_update_ui_for_mode()

func _on_login():
	"""Handle login (accept everything for now)"""
	visible = false
	lobby_panel.visible = true

func _on_register():
	"""Handle registration (accept everything for now)"""
	visible = false
	lobby_panel.visible = true
