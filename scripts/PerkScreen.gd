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
	bind_button.pressed.connect(_on_bind_pressed)
	bind_button.disabled = true
	visible = false
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	# Refresh perk data from databases in case they weren't ready when perks were created
	GameInfo.refresh_all_perks()
	refresh_perks()

func refresh_perks():
	print("Refreshing perks grid...")
	
	for child in inactive_perks_grid.get_children():
		child.queue_free()
	
	var game_perks = GameInfo.current_player.perks
	var all_perks = []
	
	for perk in game_perks:
		all_perks.append(perk)
	
	all_perks.sort_custom(func(a, b): return a.slot < b.slot)
	
	for perk in all_perks:
		var perk_button = perk_scene.instantiate()
		
		var texture_rect = perk_button.get_node("AspectRatioContainer/TextureRect")
		var label = perk_button.get_node("Label")
		
		texture_rect.texture = perk.texture
		label.text = perk.perk_name
		
		if perk.active:
			perk_button.modulate = Color(0.5, 1.0, 0.5, 1)
		else:
			perk_button.modulate = Color(1, 1, 1, 1)
		
		perk_button.set_meta("perk_data", perk)
		perk_button.pressed.connect(_on_perk_clicked.bind(perk_button, perk))
		inactive_perks_grid.add_child(perk_button)
	
	print("Loaded ", all_perks.size(), " perks")

func load_active_perks_for_slot(slot: int):
	"""Called when opening the perk screen for a specific active slot (1-3)"""
	print("Loading perks for slot: ", slot)
	current_slot = slot
	
	# Ensure perk data is refreshed from databases
	GameInfo.refresh_all_perks()
	
	# Refresh the perk grid to show current state
	refresh_perks()
	
	# Check if there's already an active perk in this slot
	var active_perk = _get_active_perk_for_slot(slot)
	print("Active perk for slot ", slot, ": ", active_perk.perk_name if active_perk else "None")
	if active_perk:
		# Show the currently active perk in the display
		_update_active_display(active_perk)
	else:
		# Clear the display
		_clear_active_display()

func _get_active_perk_for_slot(slot: int) -> GameInfo.Perk:
	"""Find the active perk for the given slot"""
	print("[PerkScreen] Looking for active perk in slot ", slot)
	print("[PerkScreen] Total perks: ", GameInfo.current_player.perks.size())
	for perk in GameInfo.current_player.perks:
		print("[PerkScreen]   Perk: ", perk.perk_name, " active=", perk.active, " slot=", perk.slot)
		if perk.active and perk.slot == slot:
			return perk
	return null

func _on_perk_clicked(perk_button: Button, perk: GameInfo.Perk):
	print("Perk clicked:", perk.perk_name)
	
	selected_perk = perk
	selected_perk_button = perk_button
	bind_button.disabled = false
	_update_perk_selection_visuals()
	_update_active_display(perk)

func _update_perk_selection_visuals():
	for child in inactive_perks_grid.get_children():
		if child is Button:
			if child.has_meta("perk_data"):
				var perk_data = child.get_meta("perk_data")
				if perk_data.active:
					child.modulate = Color(0.5, 1.0, 0.5, 1)
				else:
					child.modulate = Color(1, 1, 1, 1)
			else:
				child.modulate = Color(1, 1, 1, 1)
	
	if selected_perk_button:
		selected_perk_button.modulate = Color(1.3, 1.3, 0.5, 1)

func _update_active_display(perk: GameInfo.Perk):
	if not perk:
		_clear_active_display()
		return
	
	perk_icon.texture = perk.texture
	
	if perk.effect1_description != "":
		var effect1_text = perk.effect1_description
		if perk.factor1 != 0.0:
			effect1_text += " " + str(int(perk.factor1)) + "%"
		effect1_label.text = effect1_text
		effect1_label.visible = true
	else:
		effect1_label.text = ""
		effect1_label.visible = false
	
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
	perk_icon.texture = null
	effect1_label.text = ""
	effect1_label.visible = false
	effect2_label.text = ""
	effect2_label.visible = false

func _on_bind_pressed():
	if not selected_perk:
		print("No perk selected to bind")
		return
	
	print("Binding perk '", selected_perk.perk_name, "' to slot ", current_slot)
	
	var existing_perk = _get_active_perk_for_slot(current_slot)
	
	if existing_perk:
		existing_perk.active = false
		existing_perk.slot = _get_next_inactive_slot()
		print("Deactivated perk '", existing_perk.perk_name, "' from slot ", current_slot)
	
	selected_perk.active = true
	selected_perk.slot = current_slot
	
	# Find the talent_id that unlocks this perk slot
	var talent_id = _get_talent_id_for_perk_slot(current_slot)
	if talent_id > 0:
		Websocket.activate_perk(talent_id, selected_perk.id)
	else:
		print("[PerkScreen] ERROR: Could not find talent_id for perk_slot ", current_slot)
	
	UIManager.instance.refresh_active_effects()
	_update_active_display(selected_perk)
	refresh_perks()
	
	selected_perk = null
	selected_perk_button = null
	bind_button.disabled = true
	
	print("Perk bound successfully")

func _get_next_inactive_slot() -> int:
	"""Find the next available slot number for inactive perks"""
	var max_slot = 0
	for perk in GameInfo.current_player.perks:
		if not perk.active and perk.slot > max_slot:
			max_slot = perk.slot
	return max_slot + 1

func _get_talent_id_for_perk_slot(perk_slot_num: int) -> int:
	"""Find the talent_id that unlocks the given perk slot"""
	# Search through talent_registry to find which talent has this perk_slot
	for talent_id in GameInfo.talent_registry:
		var talent_meta = GameInfo.talent_registry[talent_id]
		if talent_meta.perk_slot == perk_slot_num:
			return talent_id
	return 0  # Not found

func _on_button_pressed():
	visible = false
