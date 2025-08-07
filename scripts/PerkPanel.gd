extends Control

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
	
	# Check if dropping within the same panel
	if source_container == self:
		print("Dropping within same panel")
		if panel_type == "Active":
			# For active panels, same-slot drops do nothing
			return
		elif panel_type == "Inactive":
			# For inactive panels, implement reordering
			_handle_reorder(_pos, data)
			return
	
	if panel_type == "Active":
		_handle_active_drop(perk, source_container)
	elif panel_type == "Inactive":
		_handle_inactive_drop(perk, source_container)

func _handle_active_drop(perk: GameInfo.Perk, source_container: Control):
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

func _handle_inactive_drop(perk: GameInfo.Perk, source_container: Control):
	print("Moving perk to inactive panel")
	# Place perk in inactive panel
	place_perk_in_panel(perk)
	
	# Only clear the source container if it's different from this panel
	if source_container and source_container != self:
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

func _handle_reorder(pos: Vector2, data):
	# Get the dragged perk
	var perk_data = data["perk"]
	var dragged_node = data.get("source_node", null)
	
	# Find the best insertion point based on mouse position
	var children = get_children()
	var insert_index = children.size()  # Default to end
	
	for i in range(children.size()):
		var child = children[i]
		var child_rect = child.get_rect()
		var child_center_y = child_rect.position.y + child_rect.size.y / 2
		
		if pos.y < child_center_y:
			insert_index = i
			break
	
	# Remove the dragged node from its current position
	if dragged_node and dragged_node.get_parent() == self:
		var current_index = dragged_node.get_index()
		# Adjust insert index if we're moving down
		if insert_index > current_index:
			insert_index -= 1
		dragged_node.get_parent().remove_child(dragged_node)
		add_child(dragged_node)
		move_child(dragged_node, insert_index)
	else:
		# Create new perk at the desired position
		var new_perk = perk_scene.instantiate()
		if not new_perk.get_script():
			new_perk.set_script(PerkDragScript)
		new_perk.set_perk_data(perk_data)
		add_child(new_perk)
		move_child(new_perk, insert_index)

func clear_panel():
	for child in get_children():
		child.queue_free()

func set_slot_filter(slot: int):
	slot_filter = slot
