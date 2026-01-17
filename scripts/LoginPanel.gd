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

# Password input and toggle
@export var password_input: LineEdit
@export var password_toggle: CheckBox

# Forgot password panel
@export var forgot_password_panel: Control
@export var forgot_password_button: Button
@export var forgot_email_input: LineEdit
@export var forgot_submit_button: Button
@export var forgot_cancel_button: Button
@export var forgot_input_panel: Control
@export var forgot_confirmation_panel: Control
@export var forgot_confirmation_email: Label
@export var forgot_confirmation_ok: Button

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
	
	# Connect method selection buttons (using toggled for toggle buttons)
	email_button.toggled.connect(_on_email_toggled)
	facebook_button.toggled.connect(_on_facebook_toggled)
	google_button.toggled.connect(_on_google_toggled)
	steam_button.toggled.connect(_on_steam_toggled)
	
	# Connect login buttons
	email_login_button.pressed.connect(_on_login)
	facebook_login_button.pressed.connect(_on_login_or_register)
	google_login_button.pressed.connect(_on_login_or_register)
	steam_login_button.pressed.connect(_on_login_or_register)
	
	# Connect register buttons
	email_register_button.pressed.connect(_on_register)
	
	# Connect password toggle checkbox
	if password_toggle:
		password_toggle.toggled.connect(_on_password_toggle)
	
	# Connect forgot password button
	if forgot_password_button:
		forgot_password_button.pressed.connect(_on_forgot_password_clicked)
	
	if forgot_submit_button:
		forgot_submit_button.pressed.connect(_on_forgot_submit)
	
	if forgot_cancel_button:
		forgot_cancel_button.pressed.connect(_on_forgot_cancel)
	
	if forgot_confirmation_ok:
		forgot_confirmation_ok.pressed.connect(_on_forgot_cancel)
	
	# Connect overlay click to close
	if forgot_password_panel:
		forgot_password_panel.gui_input.connect(_on_overlay_click)
	
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
	
	# Update indicator visibility
	if email_button:
		var email_indicator = email_button.get_node_or_null("Indicator")
		if email_indicator:
			email_indicator.visible = (method == "email")
	
	if facebook_button:
		var fb_indicator = facebook_button.get_node_or_null("Indicator")
		if fb_indicator:
			fb_indicator.visible = (method == "facebook")
	
	if google_button:
		var google_indicator = google_button.get_node_or_null("Indicator")
		if google_indicator:
			google_indicator.visible = (method == "google")
	
	if steam_button:
		var steam_indicator = steam_button.get_node_or_null("Indicator")
		if steam_indicator:
			steam_indicator.visible = (method == "steam")

func _on_email_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("email")

func _on_facebook_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("facebook")

func _on_google_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("google")

func _on_steam_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("steam")

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

func _on_password_toggle(toggled_on: bool):
	"""Toggle password visibility"""
	if password_input:
		password_input.secret = not toggled_on

func _on_forgot_password_clicked():
	"""Show the forgot password panel"""
	if forgot_password_panel:
		forgot_password_panel.visible = true
		if forgot_input_panel:
			forgot_input_panel.visible = true
		if forgot_confirmation_panel:
			forgot_confirmation_panel.visible = false
		if forgot_email_input:
			forgot_email_input.text = ""
			forgot_email_input.grab_focus()

func _on_forgot_submit():
	"""Submit forgot password request"""
	if forgot_email_input and forgot_email_input.text != "":
		var email = forgot_email_input.text
		Http.reset_password(email)
		print("Password reset email sent to: ", email)
		
		# Show confirmation panel
		if forgot_input_panel:
			forgot_input_panel.visible = false
		if forgot_confirmation_panel:
			forgot_confirmation_panel.visible = true
			# Update the email in confirmation text
			if forgot_confirmation_email:
				var text = "We have sent a new password to " + email + ".\n\n"
				text += "Please check your email inbox as well as your spam inbox.\n\n"
				text += "The new password will be activated as soon as you log in with it for the first time. "
				text += "When you log in, your current password will become invalid and you will be logged out on all other devices."
				forgot_confirmation_email.text = text

func _on_forgot_cancel():
	"""Cancel forgot password and close panel"""
	if forgot_password_panel:
		forgot_password_panel.visible = false
		if forgot_input_panel:
			forgot_input_panel.visible = true
		if forgot_confirmation_panel:
			forgot_confirmation_panel.visible = false

func _on_overlay_click(event: InputEvent):
	"""Close forgot password panel when clicking on overlay"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Only close if clicking on the overlay itself, not the panels
			if forgot_password_panel and forgot_password_panel.visible:
				_on_forgot_cancel()
