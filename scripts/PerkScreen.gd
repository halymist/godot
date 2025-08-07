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
	
	# Get all inactive perks from GameInfo
	var game_perks = GameInfo.current_player.perks
	var inactive_count = 0
	
	for perk in game_perks:
		if not perk.active:  # Only inactive perks
			print("Loading inactive perk:", perk.perk_name, "Slot:", perk.slot)
			var perk_instance = perk_scene.instantiate()
			_setup_perk_instance(perk_instance, perk)
			inactive_panel.add_child(perk_instance)
			inactive_count += 1
	
	print("Loaded ", inactive_count, " inactive perks")

func load_active_perks_for_slot(slot: int):
	print("Loading active perks for slot: ", slot)
	
	if not active_panel:
		print("Error: active_panel is null")
		return
	
	_clear_panel_children(active_panel)
	
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
	visible = false
