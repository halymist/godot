extends Control

# Login panel for authentication
@export var lobby_panel: Control

# Mode toggle buttons
@export var login_mode_button: Button
@export var register_mode_button: Button

# Login method buttons
@export var email_button: TextureButton
@export var facebook_button: TextureButton
@export var google_button: TextureButton
@export var steam_button: TextureButton

# Login sections
@export var email_login_section: Control
@export var facebook_login_section: Control
@export var google_login_section: Control
@export var steam_login_section: Control

# Register sections (only email needs separate UI)
@export var email_register_section: Control

# Login action buttons
@export var email_login_button: Button
@export var facebook_login_button: Button
@export var google_login_button: Button
@export var steam_login_button: Button

# Register action buttons (only email needs separate button)
@export var email_register_button: Button

var current_method: String = "email"
var is_register_mode: bool = false

func _ready():
	# Check if we already have login data (auto-login)
	if not GameInfo.lobby_data.is_empty():
		visible = false
		lobby_panel.visible = true
		return
	
	# Connect mode toggle buttons
	login_mode_button.toggled.connect(_on_login_mode_toggled)
	register_mode_button.toggled.connect(_on_register_mode_toggled)
	
	# Connect method selection buttons
	email_button.pressed.connect(_on_method_selected.bind("email"))
	facebook_button.pressed.connect(_on_method_selected.bind("facebook"))
	google_button.pressed.connect(_on_method_selected.bind("google"))
	steam_button.pressed.connect(_on_method_selected.bind("steam"))
	
	# Connect login buttons
	email_login_button.pressed.connect(_on_login)
	facebook_login_button.pressed.connect(_on_login_or_register)
	google_login_button.pressed.connect(_on_login_or_register)
	steam_login_button.pressed.connect(_on_login_or_register)
	
	# Connect register buttons
	email_register_button.pressed.connect(_on_register)
	
	# Start with login mode and email selected
	_on_mode_toggle(false)
	_on_method_selected("email")

func _on_mode_toggle(register: bool):
	"""Toggle between login and register mode"""
	is_register_mode = register
	_update_ui_for_mode()

func _on_login_mode_toggled(toggled_on: bool):
	"""Handle login button toggle"""
	if toggled_on:
		_on_mode_toggle(false)

func _on_register_mode_toggled(toggled_on: bool):
	"""Handle register button toggle"""
	if toggled_on:
		_on_mode_toggle(true)

func _update_ui_for_mode():
	"""Update UI to show login or register sections"""
	if is_register_mode:
		# Email has separate register section
		email_register_section.visible = current_method == "email"
		email_login_section.visible = false
		# Non-email methods reuse login sections for both modes
		facebook_login_section.visible = current_method == "facebook"
		google_login_section.visible = current_method == "google"
		steam_login_section.visible = current_method == "steam"
	else:
		# Show login sections
		email_login_section.visible = current_method == "email"
		facebook_login_section.visible = current_method == "facebook"
		google_login_section.visible = current_method == "google"
		steam_login_section.visible = current_method == "steam"
		# Hide email register section
		email_register_section.visible = false

func _on_method_selected(method: String):
	"""Show the selected login method section"""
	current_method = method
	_update_ui_for_mode()

func _on_login():
	"""Handle login (accept everything for now)"""
	# Load lobby data (simulates successful login)
	GameInfo.load_lobby_data()
	visible = false
	lobby_panel.visible = true

func _on_login_or_register():
	"""Handle login or register for non-email methods (same flow)"""
	# Load lobby data (simulates successful login/register)
	GameInfo.load_lobby_data()
	visible = false
	lobby_panel.visible = true

func _on_register():
	"""Handle registration (accept everything for now)"""
	# Load lobby data (simulates successful registration)
	GameInfo.load_lobby_data()
	visible = false
	lobby_panel.visible = true
