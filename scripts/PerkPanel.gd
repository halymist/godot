extends Panel

@export var panel_type: String = "Active" # "Active" or "Inactive"
@export var perk_scene: PackedScene
var slot_filter: int = 0 # Which perk slot this active panel is showing

# Preload the PerkDrag script
const PerkDragScript = preload("res://scripts/PerkDrag.gd")

func _can_drop_data(_pos, data):
	# Check if data is valid drag package
	if not (data is Dictionary and data.has("perk") and data["perk"] is GameInfo.Perk):
		return false
	
	# For active panel, we accept any perk
	if panel_type == "Active":
		return true
	
	# For inactive panel, we accept any perk for deactivating/reordering
	if panel_type == "Inactive":
		return true
	
	return false

func _drop_data(_pos, data):
	# Extract perk and source container from drag package
	var perk = data["perk"]
	var source_container = data["source_container"]
	
	print("Dropping perk '", perk.perk_name, "' on ", panel_type, " panel")
	
	if panel_type == "Active":
		_handle_active_drop(perk, source_container)
	elif panel_type == "Inactive":
		_handle_inactive_drop(perk, source_container)

func _handle_active_drop(perk: GameInfo.Perk, source_container: Panel):
	# Check if active panel already has a perk (need to swap)
	var existing_children = get_children()
	if existing_children.size() > 0:
		var existing_perk_node = existing_children[0]
		var existing_perk_data = existing_perk_node.get_perk_data()
		
		print("Active panel has existing perk, swapping...")
		
		# Place existing perk in source container
		if source_container:
			source_container.place_perk_in_panel(existing_perk_data)
		
		# Clear this panel and place new perk
		clear_panel()
		place_perk_in_panel(perk)
	else:
		print("Active panel is empty, moving perk...")
		# Just place the perk in active panel
		place_perk_in_panel(perk)
	
	# Clear the source container
	if source_container:
		source_container.clear_panel()

func _handle_inactive_drop(perk: GameInfo.Perk, source_container: Panel):
	print("Moving perk to inactive panel")
	# Place perk in inactive panel
	place_perk_in_panel(perk)
	
	# Clear the source container
	if source_container:
		source_container.clear_panel()

func place_perk_in_panel(perk_data: GameInfo.Perk):
	print("Placing perk '", perk_data.perk_name, "' in panel: ", self.name)
	
	# Create new perk instance
	var new_perk = perk_scene.instantiate()
	
	# Set up the perk instance with the PerkDrag script if it doesn't have one
	if not new_perk.get_script():
		new_perk.set_script(PerkDragScript)
	
	# Set the perk data using the script's method
	new_perk.set_perk_data(perk_data)
	add_child(new_perk)
	
	print("Perk placed successfully, panel now has ", get_child_count(), " children")

func clear_panel():
	for child in get_children():
		child.queue_free()

func set_slot_filter(slot: int):
	slot_filter = slot
