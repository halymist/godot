extends Panel

# Lobby panel for character selection and account management

@export var game_title_label: Label
@export var account_info_container: VBoxContainer
@export var login_methods_container: HBoxContainer
@export var characters_container: VBoxContainer

func _ready():
	setup_ui()

func setup_ui():
	"""Initialize the lobby UI with placeholder content"""
	# Set game title
	if game_title_label:
		game_title_label.text = "Wilds"
	
	# Setup account info
	if account_info_container:
		add_account_info()
	
	# Setup login methods
	if login_methods_container:
		add_login_methods()
	
	# Setup character list
	if characters_container:
		add_character_list()

func add_account_info():
	"""Add account information labels"""
	var creation_label = Label.new()
	creation_label.text = "Account Created: January 1, 2026"
	account_info_container.add_child(creation_label)
	
	var email_label = Label.new()
	email_label.text = "Email: player@example.com"
	account_info_container.add_child(email_label)

func add_login_methods():
	"""Add login method icons"""
	var methods = ["Google", "Email", "Steam", "Discord"]
	
	for method in methods:
		var button = Button.new()
		button.text = method[0]  # First letter as placeholder
		button.custom_minimum_size = Vector2(60, 60)
		button.tooltip_text = method
		login_methods_container.add_child(button)

func add_character_list():
	"""Add character panels and create new button"""
	# Add 2 example characters
	for i in range(2):
		var char_panel = create_character_panel(
			"Character " + str(i + 1),
			"Server " + str(i + 1),
			str(10 + i) + " days"
		)
		characters_container.add_child(char_panel)
	
	# Add "Create New" button
	var create_panel = create_new_character_panel()
	characters_container.add_child(create_panel)

func create_character_panel(char_name: String, server: String, age: String) -> PanelContainer:
	"""Create a character selection panel"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Icon placeholder
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.color = Color(0.3, 0.3, 0.4, 1)
	hbox.add_child(icon)
	
	# Character info
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = char_name
	vbox.add_child(name_label)
	
	var server_label = Label.new()
	server_label.text = "Server: " + server
	vbox.add_child(server_label)
	
	var age_label = Label.new()
	age_label.text = "Age: " + age
	vbox.add_child(age_label)
	
	# Make panel clickable
	var button = Button.new()
	button.text = "Select"
	hbox.add_child(button)
	
	return panel

func create_new_character_panel() -> PanelContainer:
	"""Create the 'Create New Character' panel"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	
	var hbox = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Plus icon placeholder
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.color = Color(0.2, 0.6, 0.3, 1)
	hbox.add_child(icon)
	
	var label = Label.new()
	label.text = "Create New Character"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	
	return panel
