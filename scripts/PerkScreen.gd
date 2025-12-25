extends Button

@export var active_panel: Control
@export var inactive_panel: Control
@export var perk_scene: PackedScene

var perks: Array = []

func _ready():
	pressed.connect(_on_button_pressed)
	visible = false
	
	
	load_inactive_perks()  # Load inactive perks once

func load_inactive_perks():
	print("Loading all inactive perks...")
	
	if not inactive_panel:
		print("Error: inactive_panel is null")
		return
	
	# Clear existing inactive perk nodes
	_clear_panel_children(inactive_panel)
	
	# Get all inactive perks from GameInfo and sort by slot
	var game_perks = GameInfo.current_player.perks
	var inactive_perks = []
	
	for perk in game_perks:
		if not perk.active:  # Only inactive perks
			inactive_perks.append(perk)
	
	# Sort by slot number
	inactive_perks.sort_custom(func(a, b): return a.slot < b.slot)
	
	# Add perks to panel in order
	for perk in inactive_perks:
		print("Loading inactive perk:", perk.perk_name, "Slot:", perk.slot)
		var perk_instance = perk_scene.instantiate()
		_setup_perk_instance(perk_instance, perk)
		inactive_panel.add_child(perk_instance)
	
	print("Loaded ", inactive_perks.size(), " inactive perks")

func load_active_perks_for_slot(slot: int):
	print("Loading active perks for slot: ", slot)
	
	if not active_panel:
		print("Error: active_panel is null")
		return
	
	# Set the slot filter on the active panel so it knows which perk_slot it represents
	if active_panel.has_method("set_slot_filter"):
		active_panel.set_slot_filter(slot)
	
	_clear_panel_children(active_panel)
	
	# Reload inactive perks to reflect any changes (e.g., after talent reset)
	load_inactive_perks()
	
	# Get active perks for the specific slot from GameInfo
	var game_perks = GameInfo.current_player.perks
	var active_count = 0
	
	for perk in game_perks:
		if perk.active and perk.slot == slot:
			print("Loading active perk:", perk.perk_name, "Slot:", perk.slot)
			var perk_instance = perk_scene.instantiate()
			_setup_perk_instance(perk_instance, perk)
			active_panel.add_child(perk_instance)
			active_count += 1
	
	print("Loaded ", active_count, " active perks for slot ", slot)

func _clear_panel_children(panel: Control):
	for child in panel.get_children():
		child.queue_free()

func _setup_perk_instance(perk_instance: Node, perk: GameInfo.Perk):
	# Set up the perk instance with the PerkDrag script
	if not perk_instance.get_script():
		var perk_script = load("res://scripts/PerkDrag.gd")
		perk_instance.set_script(perk_script)
	
	# Set the perk data using the script's method
	perk_instance.set_perk_data(perk)

func _on_button_pressed():
	# Clear from GameInfo when closing via background click
	if GameInfo.get_current_panel_overlay() == self:
		GameInfo.set_current_panel_overlay(null)
	visible = false

func show_overlay():
	"""Show the perk screen with slide up animation"""
	# Make visible first
	visible = true
	
	# Start positioned below the screen
	var viewport_height = get_viewport().get_visible_rect().size.y
	position.y = viewport_height
	
	# Slide up animation
	var show_tween = create_tween()
	show_tween.set_ease(Tween.EASE_OUT)
	show_tween.set_trans(Tween.TRANS_CUBIC)
	show_tween.tween_property(self, "position:y", 0, 0.3)

func hide_overlay():
	"""Hide the perk screen with slide down animation"""
	var hide_tween = create_tween()
	hide_tween.set_ease(Tween.EASE_IN)
	hide_tween.set_trans(Tween.TRANS_CUBIC)
	hide_tween.tween_property(self, "position:y", get_viewport().get_visible_rect().size.y, 0.25)
	hide_tween.tween_callback(func(): visible = false)
