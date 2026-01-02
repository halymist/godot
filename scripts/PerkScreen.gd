extends Button

@export var active_perk_display: Control
@export var inactive_perks_grid: GridContainer
@export var bind_button: Button
@export var effect1_label: Label
@export var effect2_label: Label
@export var perk_icon: TextureRect
@export var perk_scene: PackedScene

var current_slot: int = 0  # Which active perk slot (1-3) we're binding to
var selected_perk: GameInfo.Perk = null
var selected_perk_button: Button = null

func _ready():
	pressed.connect(_on_button_pressed)
	if bind_button:
		bind_button.pressed.connect(_on_bind_pressed)
		bind_button.disabled = true
	visible = false

func load_inactive_perks():
	"""Load all inactive perks into the grid"""
	print("Loading inactive perks into grid...")
	
	if not inactive_perks_grid:
		print("Error: inactive_perks_grid is null")
		return
	
	# Clear existing perk buttons
	for child in inactive_perks_grid.get_children():
		child.queue_free()
	
	# Get all inactive perks from GameInfo and sort by slot
	var game_perks = GameInfo.current_player.perks
	var inactive_perks = []
	
	for perk in game_perks:
		if not perk.active:  # Only inactive perks
			inactive_perks.append(perk)
	
	# Sort by slot number
	inactive_perks.sort_custom(func(a, b): return a.slot < b.slot)
	
	# Create perk buttons in grid
	for perk in inactive_perks:
		print("Creating perk button:", perk.perk_name)
		var perk_button = perk_scene.instantiate()
		
		# Set perk data
		var texture_rect = perk_button.get_node("AspectRatioContainer/TextureRect")
		var label = perk_button.get_node("Label")
		
		if texture_rect:
			texture_rect.texture = perk.texture
		if label:
			label.text = perk.perk_name
		
		# Store perk data reference
		perk_button.set_meta("perk_data", perk)
		
		# Connect click signal
		perk_button.pressed.connect(_on_perk_clicked.bind(perk_button, perk))
		
		inactive_perks_grid.add_child(perk_button)
	
	print("Loaded ", inactive_perks.size(), " inactive perks")

func load_active_perks_for_slot(slot: int):
	"""Called when opening the perk screen for a specific active slot (1-3)"""
	print("Loading perks for slot: ", slot)
	current_slot = slot
	
	# Load all inactive perks
	load_inactive_perks()
	
	# Check if there's already an active perk in this slot
	var active_perk = _get_active_perk_for_slot(slot)
	if active_perk:
		# Show the currently active perk in the display
		_update_active_display(active_perk)
	else:
		# Clear the display
		_clear_active_display()

func _get_active_perk_for_slot(slot: int) -> GameInfo.Perk:
	"""Find the active perk for the given slot"""
	for perk in GameInfo.current_player.perks:
		if perk.active and perk.slot == slot:
			return perk
	return null

func _on_perk_clicked(perk_button: Button, perk: GameInfo.Perk):
	"""Handle clicking on an inactive perk"""
	print("Perk clicked:", perk.perk_name)
	
	# Update selection
	selected_perk = perk
	selected_perk_button = perk_button
	
	# Enable bind button now that a perk is selected
	if bind_button:
		bind_button.disabled = false
	
	# Update visual feedback - highlight selected perk
	_update_perk_selection_visuals()
	
	# Update the active perk display
	_update_active_display(perk)

func _update_perk_selection_visuals():
	"""Update visual feedback for which perk is selected"""
	# Reset all perk buttons to normal style
	for child in inactive_perks_grid.get_children():
		if child is Button:
			child.modulate = Color(1, 1, 1, 1)
	
	# Highlight the selected perk
	if selected_perk_button:
		selected_perk_button.modulate = Color(1.3, 1.3, 1, 1)

func _update_active_display(perk: GameInfo.Perk):
	"""Update the active perk display area with perk details"""
	if not perk:
		_clear_active_display()
		return
	
	# Update icon
	if perk_icon:
		perk_icon.texture = perk.texture
	
	# Update effect 1
	if effect1_label:
		if perk.effect1_description != "":
			var effect1_text = perk.effect1_description
			if perk.factor1 != 0.0:
				effect1_text += " " + str(int(perk.factor1)) + "%"
			effect1_label.text = effect1_text
			effect1_label.visible = true
		else:
			effect1_label.text = ""
			effect1_label.visible = false
	
	# Update effect 2
	if effect2_label:
		if perk.effect2_description != "":
			var effect2_text = perk.effect2_description
			if perk.factor2 != 0.0:
				effect2_text += " " + str(int(perk.factor2)) + "%"
			effect2_label.text = effect2_text
			effect2_label.visible = true
		else:
			effect2_label.text = ""
			effect2_label.visible = false

func _clear_active_display():
	"""Clear the active perk display"""
	if perk_icon:
		perk_icon.texture = null
	if effect1_label:
		effect1_label.text = ""
		effect1_label.visible = false
	if effect2_label:
		effect2_label.text = ""
		effect2_label.visible = false

func _on_bind_pressed():
	"""Handle the bind button being pressed"""
	if not selected_perk:
		print("No perk selected to bind")
		return
	
	print("Binding perk '", selected_perk.perk_name, "' to slot ", current_slot)
	
	# Check if there's already an active perk in this slot
	var existing_perk = _get_active_perk_for_slot(current_slot)
	
	if existing_perk:
		# Deactivate the existing perk
		existing_perk.active = false
		# Give it a new slot number (find the next available inactive slot)
		existing_perk.slot = _get_next_inactive_slot()
		print("Deactivated perk '", existing_perk.perk_name, "' from slot ", current_slot)
	
	# Activate the selected perk
	selected_perk.active = true
	selected_perk.slot = current_slot
	
	# Refresh active effects display
	if UIManager.instance:
		UIManager.instance.refresh_active_effects()
	
	# TODO: Send update to server
	# Websocket.send_perk_update(selected_perk)
		# Clear selection and disable bind button
	selected_perk = null
	selected_perk_button = null
	if bind_button:
		bind_button.disabled = true
		# Reload the perks display
	load_active_perks_for_slot(current_slot)
	
	print("Perk bound successfully")

func _get_next_inactive_slot() -> int:
	"""Find the next available slot number for inactive perks"""
	var max_slot = 0
	for perk in GameInfo.current_player.perks:
		if not perk.active and perk.slot > max_slot:
			max_slot = perk.slot
	return max_slot + 1

func _on_button_pressed():
	"""Handle clicking the background to close"""
	if GameInfo.get_current_panel_overlay() == self:
		GameInfo.set_current_panel_overlay(null)
	visible = false

func show_overlay():
	"""Show the perk screen"""
	position.y = 0
	visible = true

func hide_overlay():
	"""Hide the perk screen"""
	visible = false
