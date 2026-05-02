extends Control

# Login panel for authentication
@export var lobby_panel: Control

# Mode toggle buttons
@export var login_mode_button: Button
@export var register_mode_button: Button

# Login method buttons
@export var email_button: TextureButton
@export var google_button: TextureButton
@export var google_play_button: TextureButton
@export var apple_button: TextureButton
@export var discord_button: TextureButton
@export var facebook_button: TextureButton
@export var method_indicator: Panel

# Login sections
@export var email_login_section: Control
@export var google_login_section: Control
@export var google_play_login_section: Control
@export var apple_login_section: Control
@export var discord_login_section: Control
@export var facebook_login_section: Control

# Register sections (only email needs separate UI)
@export var email_register_section: Control

# Login action buttons
@export var email_login_button: Button
@export var google_login_button: Button
@export var google_play_login_button: Button
@export var apple_login_button: Button
@export var discord_login_button: Button
@export var facebook_login_button: Button

# Register action buttons (only email needs separate button)
@export var email_register_button: Button

# Email/Password inputs
@export var email_input: LineEdit
@export var password_input: LineEdit
@export var password_toggle: CheckBox
@export var stay_logged_in_checkbox: CheckBox

# Error display
@export var error_label: Label

# Credential storage path
const CREDENTIALS_PATH = "user://credentials.cfg"

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
var indicator_tween: Tween
var is_logging_in: bool = false  # Prevent double-clicks during login
var _dot_tween: Tween
var _dot_base_text: String = ""

func _ready():

	# Check if we already have login data (returning from game)
	if not GameInfo.lobby_data.is_empty():
		_start_dot_animation("Loading")
		_show_lobby_after_init()
		return
	
	# Connect HTTP login signal
	if not Http.login_completed.is_connected(_on_login_completed):
		Http.login_completed.connect(_on_login_completed)
	
	# Try to auto-login with saved credentials (unless explicitly skipped)
	if GameInfo.skip_auto_login_once:
		GameInfo.skip_auto_login_once = false
		_prefill_saved_credentials()
	else:
		_try_auto_login()
	
	# Connect mode toggle buttons
	login_mode_button.toggled.connect(_on_login_mode_toggled)
	register_mode_button.toggled.connect(_on_register_mode_toggled)
	
	# Connect method selection buttons (using toggled for toggle buttons)
	email_button.toggled.connect(_on_email_toggled)
	google_button.toggled.connect(_on_google_toggled)
	google_play_button.toggled.connect(_on_google_play_toggled)
	apple_button.toggled.connect(_on_apple_toggled)
	discord_button.toggled.connect(_on_discord_toggled)
	facebook_button.toggled.connect(_on_facebook_toggled)
	
	# Connect login buttons
	email_login_button.pressed.connect(_on_login)
	google_login_button.pressed.connect(_on_login_or_register)
	google_play_login_button.pressed.connect(_on_login_or_register)
	apple_login_button.pressed.connect(_on_login_or_register)
	discord_login_button.pressed.connect(_on_login_or_register)
	facebook_login_button.pressed.connect(_on_login_or_register)
	
	# Submit on Enter in email/password fields
	if email_input:
		email_input.text_submitted.connect(_on_email_submitted)
	if password_input:
		password_input.text_submitted.connect(_on_password_submitted)
	
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
	
	# Hide error label initially
	if error_label:
		error_label.visible = false
	
	# Start with login mode and email selected
	_on_mode_toggle(false)
	# Defer so button layout is finalized before we calculate indicator position
	call_deferred("_on_method_selected", "email")

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
		google_login_section.visible = current_method == "google"
		google_play_login_section.visible = current_method == "google_play"
		apple_login_section.visible = current_method == "apple"
		discord_login_section.visible = current_method == "discord"
		facebook_login_section.visible = current_method == "facebook"
	else:
		# Show login sections
		email_login_section.visible = current_method == "email"
		google_login_section.visible = current_method == "google"
		google_play_login_section.visible = current_method == "google_play"
		apple_login_section.visible = current_method == "apple"
		discord_login_section.visible = current_method == "discord"
		facebook_login_section.visible = current_method == "facebook"
		# Hide email register section
		email_register_section.visible = false

func _on_method_selected(method: String):
	"""Show the selected login method section"""
	current_method = method
	_update_ui_for_mode()
	
	# Animate indicator to the selected button
	_animate_indicator_to_button(method)

func _animate_indicator_to_button(method: String):
	"""Animate the indicator to the selected button position"""
	if not method_indicator:
		return
	
	var target_button: TextureButton = null
	match method:
		"email":
			target_button = email_button
		"google":
			target_button = google_button
		"google_play":
			target_button = google_play_button
		"apple":
			target_button = apple_button
		"discord":
			target_button = discord_button
		"facebook":
			target_button = facebook_button
	
	if not target_button:
		return
	
	# Calculate target x position (center below button), keep y position fixed
	var button_center_x = target_button.position.x + target_button.size.x / 2
	var target_x = button_center_x - method_indicator.size.x / 2
	
	# Kill existing tween if any
	if indicator_tween:
		indicator_tween.kill()
	
	# Create new tween animation (only animate x position)
	indicator_tween = create_tween()
	indicator_tween.set_ease(Tween.EASE_OUT)
	indicator_tween.set_trans(Tween.TRANS_CUBIC)
	indicator_tween.tween_property(method_indicator, "position:x", target_x, 0.3)

func _on_email_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("email")

func _on_google_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("google")

func _on_google_play_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("google_play")

func _on_apple_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("apple")

func _on_discord_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("discord")

func _on_facebook_toggled(toggled_on: bool):
	if toggled_on:
		_on_method_selected("facebook")

func _on_email_submitted(_text: String):
	if not is_register_mode:
		_on_login()

func _on_password_submitted(_text: String):
	if not is_register_mode:
		_on_login()

func _on_login():
	"""Handle email/password login"""
	if is_logging_in:
		return
	
	# Get email and password
	var email = ""
	var password = ""
	
	if email_input:
		email = email_input.text.strip_edges()
	if password_input:
		password = password_input.text
	
	# Validate inputs
	if email.is_empty():
		_show_error("Please enter your email")
		return
	if password.is_empty():
		_show_error("Please enter your password")
		return
	
	# Clear any previous error
	_hide_error()
	
	# Keep button visually updating for dot animation; clicks are guarded by is_logging_in
	is_logging_in = true
	print("[Login] Starting login, calling _start_dot_animation")
	_start_dot_animation("Loading")
	
	# Send login request to server
	Http.login(email, password)

func _on_login_completed(success: bool, data: Dictionary, error: String):
	"""Handle login response from server"""
	if success:
		# Store lobby data in GameInfo
		GameInfo.lobby_data = data
		
		# Save or clear credentials based on "stay logged in" checkbox
		if stay_logged_in_checkbox and stay_logged_in_checkbox.button_pressed:
			_save_credentials()
		else:
			_clear_credentials()
		
		print("[Login] Login success, lobby init starting")
		# DON'T restart animation - keep the existing one running
		
		# Initialize lobby, wait until ready, then switch
		_show_lobby_after_init()
	else:
		# Stop animation and re-enable button
		_stop_dot_animation()
		is_logging_in = false
		if email_login_button:
			email_login_button.disabled = false
			email_login_button.text = "Login"
		
		var msg = error if error != "" else "Email or password is incorrect"
		_show_error(msg)

# ============================================
# Credential Storage Functions
# ============================================

func _try_auto_login() -> bool:
	"""Try to login with saved credentials. Returns true if attempting auto-login."""
	var config = ConfigFile.new()
	var err = config.load(CREDENTIALS_PATH)
	if err != OK:
		return false
	
	var email = config.get_value("auth", "email", "")
	var password = config.get_value("auth", "password", "")
	
	if email.is_empty() or password.is_empty():
		return false
	
	_prefill_saved_credentials()
	
	# Auto-login if we have both fields
	if not email_input.text.strip_edges().is_empty() and not password_input.text.is_empty():
		_on_login()
		return true
	
	return false

func _prefill_saved_credentials():
	"""Pre-fill the email and password fields without auto-login."""
	var config = ConfigFile.new()
	var err = config.load(CREDENTIALS_PATH)
	if err != OK:
		return
	var email = config.get_value("auth", "email", "")
	var password = config.get_value("auth", "password", "")
	if email.is_empty() or password.is_empty():
		return
	print("[Login] Found saved credentials, pre-filling login form...")
	if email_input:
		email_input.text = email
	if password_input:
		password_input.text = password
	if stay_logged_in_checkbox:
		stay_logged_in_checkbox.button_pressed = true

func _save_credentials():
	"""Save email and password to config file"""
	if not email_input or not password_input:
		return
	
	var config = ConfigFile.new()
	config.set_value("auth", "email", email_input.text.strip_edges())
	config.set_value("auth", "password", password_input.text)
	
	var err = config.save(CREDENTIALS_PATH)
	if err == OK:
		print("[Login] Credentials saved for auto-login")
	else:
		print("[Login] Failed to save credentials: ", err)

func _clear_credentials():
	"""Clear saved credentials"""
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("credentials.cfg"):
		dir.remove("credentials.cfg")
		print("[Login] Saved credentials cleared")

func _show_error(message: String):
	"""Display error message to user"""
	print("[Login] Error: ", message)
	if error_label:
		error_label.text = message
		error_label.visible = true

func _show_lobby_after_init():
	"""Keep login visible until lobby is fully initialized, then switch."""
	print("[Login] _show_lobby_after_init: waiting for lobby to be ready...")
	if not lobby_panel:
		print("[Login] ERROR: no lobby_panel!")
		_stop_dot_animation()
		is_logging_in = false
		if email_login_button:
			email_login_button.disabled = false
			email_login_button.text = "Login"
		return
	
	lobby_panel.visible = false
	lobby_panel.initialize_lobby()
	if lobby_panel.has_method("is_lobby_ready") and lobby_panel.is_lobby_ready():
		print("[Login] lobby already ready, switching immediately")
	else:
		await lobby_panel.lobby_ready
	print("[Login] lobby_ready received, switching to lobby")
	
	# Lobby is ready — switch panels
	_stop_dot_animation()
	visible = false
	lobby_panel.visible = true
	
	# Reset login button for potential future use
	is_logging_in = false
	if email_login_button:
		email_login_button.disabled = false
		email_login_button.text = "Login"

func _hide_error():
	"""Hide error message"""
	if error_label:
		error_label.visible = false

func _start_dot_animation(base_text: String):
	print("[Login] _start_dot_animation called with: '", base_text, "'")
	_stop_dot_animation()
	_dot_base_text = base_text
	if not email_login_button:
		print("[Login] ERROR: email_login_button is null!")
		return
	email_login_button.text = base_text + "."
	print("[Login] Creating tween, node in tree: ", is_inside_tree())
	var tw = create_tween()
	if tw == null:
		print("[Login] ERROR: create_tween() returned null!")
		return
	_dot_tween = tw.set_loops()
	_dot_tween.tween_callback(_set_dots.bind(1)).set_delay(0.3)
	_dot_tween.tween_callback(_set_dots.bind(2)).set_delay(0.3)
	_dot_tween.tween_callback(_set_dots.bind(3)).set_delay(0.3)
	print("[Login] Tween created successfully, looping")

func _set_dots(count: int):
	if email_login_button:
		email_login_button.text = _dot_base_text + ".".repeat(count)
		print("[Login] Dot tick: ", count, " -> '", email_login_button.text, "'")

func _stop_dot_animation():
	print("[Login] _stop_dot_animation called")
	if _dot_tween:
		_dot_tween.kill()
		_dot_tween = null

func _on_login_or_register():
	"""Handle login or register for non-email methods (same flow)"""
	# TODO: Implement OAuth flows for other providers
	# For now, show error that these methods are not yet implemented
	_show_error("This login method is not yet available")

func _on_register():
	"""Handle registration (placeholder)"""
	# TODO: Implement registration endpoint
	_show_error("Registration is not yet available")

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
