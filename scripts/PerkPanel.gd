extends Panel

@export var panel_type: String = "Active" # "Active" or "Inactive"
@export var perk_scene: PackedScene
var slot_filter: int = 0 # Which perk slot this active panel is showing

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
		
		print("Active panel has existing perk, swapping...")
		
		# Move existing perk back to source
		existing_perk_node.reparent(source_container)
		
		# Move dragged perk to active panel
		var dragged_perk_node = _find_perk_node_in_container(source_container, perk)
		if dragged_perk_node:
			dragged_perk_node.reparent(self)
	else:
		print("Active panel is empty, moving perk...")
		# Move dragged perk to active panel
		var dragged_perk_node = _find_perk_node_in_container(source_container, perk)
		if dragged_perk_node:
			dragged_perk_node.reparent(self)

func _handle_inactive_drop(perk: GameInfo.Perk, source_container: Panel):
	print("Moving perk to inactive panel")
	# Move dragged perk to inactive panel
	var dragged_perk_node = _find_perk_node_in_container(source_container, perk)
	if dragged_perk_node:
		dragged_perk_node.reparent(self)

func _find_perk_node_in_container(container: Panel, perk_data: GameInfo.Perk) -> Node:
	for child in container.get_children():
		if child.has_method("get_perk_data"):
			var child_perk = child.get_perk_data()
			if child_perk and child_perk.perk_name == perk_data.perk_name:
				return child
	return null

func clear_panel():
	for child in get_children():
		child.queue_free()

func set_slot_filter(slot: int):
	slot_filter = slot
