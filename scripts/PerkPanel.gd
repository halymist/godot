extends Control

@export var panel_type: String = "Active" # "Active" or "Inactive"
@export var perk_scene: PackedScene
var slot_filter: int = 0 # Which perk slot this active panel is showing

# Preload the PerkDrag script
const PerkDragScript = preload("res://scripts/PerkDrag.gd")

# Variables for drag feedback
var drag_placeholder: Control = null
var is_dragging_over: bool = false

func _can_drop_data(pos, data):
	# Check if data is valid drag package
	if not (data is Dictionary and data.has("perk") and data["perk"] is GameInfo.Perk):
		return false
	
	# For active panel, we accept any perk
	if panel_type == "Active":
		return true
	
	# For inactive panel, we accept any perk
	if panel_type == "Inactive":
		# Show placeholder for reordering feedback
		if not is_dragging_over:
			is_dragging_over = true
			_create_placeholder()
		_update_placeholder_position(pos)
		return true
	
	return false

# Override mouse exit to remove placeholder when mouse leaves the panel
func _input(event):
	if event is InputEventMouseMotion and is_dragging_over:
		var panel_rect = Rect2(Vector2.ZERO, size)
		var global_mouse_pos = event.global_position
		var local_mouse_pos = global_mouse_pos - global_position
		
		# If mouse is outside the panel, remove placeholder
		if not panel_rect.has_point(local_mouse_pos):
			print("Mouse left panel, removing placeholder")
			_remove_placeholder()
			is_dragging_over = false

func _drop_data(_pos, data):
	# Remove placeholder and reset drag state
	_remove_placeholder()
	is_dragging_over = false
	
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
		_handle_active_drop(perk, source_container, data)
	elif panel_type == "Inactive":
		_handle_inactive_drop(perk, source_container, data)

func _handle_active_drop(perk: GameInfo.Perk, source_container: Control, data: Dictionary):
	# Update perk data to be active
	perk.active = true
	
	# Check if active panel already has a perk (need to swap)
	var existing_children = get_children()
	if existing_children.size() > 0:
		var existing_perk_node = existing_children[0]
		var existing_perk_data = existing_perk_node.get_perk_data()
		
		print("Active panel has existing perk, swapping...")
		
		# Update existing perk to be inactive
		existing_perk_data.active = false
		
		# Place existing perk in source container
		if source_container:
			source_container.place_perk_in_panel(existing_perk_data)
		
		# Clear this panel and place new perk
		clear_panel()
		place_perk_in_panel(perk)
		
		# Only clear the source container if it's different from this panel
		if source_container and source_container != self:
			# Remove only the specific perk that was dragged
			var source_node = data.get("source_node", null)
			if source_node and source_node.get_parent() == source_container:
				source_node.queue_free()
			else:
				print("Warning: Could not find source node to remove for swap")
	else:
		print("Active panel is empty, moving perk...")
		# Just place the perk in active panel
		place_perk_in_panel(perk)
		
		# Only clear the source container if it's different from this panel
		if source_container and source_container != self:
			# Remove only the specific perk that was dragged
			var source_node = data.get("source_node", null)
			if source_node and source_node.get_parent() == source_container:
				source_node.queue_free()
			else:
				print("Warning: Could not find source node to remove for move")

func _handle_inactive_drop(perk: GameInfo.Perk, source_container: Control, data: Dictionary):
	print("Moving perk to inactive panel")
	
	# Update perk data to be inactive
	perk.active = false
	
	# Place perk in inactive panel
	place_perk_in_panel(perk)
	
	# Only clear the source container if it's different from this panel
	if source_container and source_container != self:
		# Remove only the specific perk that was dragged
		var source_node = data.get("source_node", null)
		if source_node and source_node.get_parent() == source_container:
			source_node.queue_free()
		else:
			print("Warning: Could not find source node to remove from active")

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
	
	# Update active perks display in character screen
	_update_character_active_perks()

func clear_panel():
	for child in get_children():
		if child != drag_placeholder:  # Don't clear the placeholder
			child.queue_free()
	
	# Update active perks display when clearing
	_update_character_active_perks()

func set_slot_filter(slot: int):
	slot_filter = slot

func _create_placeholder():
	if drag_placeholder:
		return
		
	drag_placeholder = Panel.new()
	drag_placeholder.custom_minimum_size = Vector2(0, 70)  # Same height as perk
	drag_placeholder.modulate = Color(1, 1, 1, 0.3)  # Semi-transparent
	drag_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Make it ignore mouse input
	
	# Add a subtle background
	var style = StyleBoxFlat.new()
	style.bg_color = Color.GRAY
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	drag_placeholder.add_theme_stylebox_override("panel", style)

func _remove_placeholder():
	if drag_placeholder and drag_placeholder.get_parent():
		drag_placeholder.get_parent().remove_child(drag_placeholder)
		drag_placeholder.queue_free()
		drag_placeholder = null

func _update_placeholder_position(pos: Vector2):
	if panel_type != "Inactive" or not drag_placeholder:
		return
	
	# Ensure placeholder is added first
	if drag_placeholder.get_parent() != self:
		add_child(drag_placeholder)
		
	# Simple logic: find which perk we're over and place placeholder accordingly
	var children = get_children()
	var insert_index = 0
	var found_target = false
	
	print("Mouse position: ", pos, " - Checking ", children.size(), " children")
	
	for i in range(children.size()):
		var child = children[i]
		if child == drag_placeholder:
			continue
			
		var child_rect = child.get_rect()
		print("Child ", i, " rect: ", child_rect, " - position: ", child_rect.position, " size: ", child_rect.size)
		
		# Check if mouse is anywhere over this child's Y range
		var child_top = child_rect.position.y
		var child_bottom = child_rect.position.y + child_rect.size.y
		
		if pos.y >= child_top and pos.y <= child_bottom:
			found_target = true
			var child_center_y = child_top + child_rect.size.y / 2
			
			# Top half = before, bottom half = after
			if pos.y < child_center_y:
				insert_index = i  # Insert before this child
				print("Mouse over TOP of perk ", i, ", inserting BEFORE at index: ", insert_index)
			else:
				insert_index = i + 1  # Insert after this child
				print("Mouse over BOTTOM of perk ", i, ", inserting AFTER at index: ", insert_index)
			break
	
	# If not over any child, place at end
	if not found_target:
		insert_index = children.size() - 1  # -1 because placeholder is already a child
		print("Mouse not over any perk, placing at END: ", insert_index)
	
	# Make sure we don't move to same position
	var current_index = drag_placeholder.get_index()
	if current_index != insert_index:
		move_child(drag_placeholder, insert_index)

# Handle drag exit to clean up placeholder
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		_remove_placeholder()
		is_dragging_over = false

func _update_character_active_perks():
	# Find and update the active perks display in character screen
	var character_panel = get_tree().root.get_node("Game/Portrait/GameScene/Character")
	if character_panel:
		var active_perks_display = character_panel.get_node("ActivePerks")
		if active_perks_display and active_perks_display.has_method("update_active_perks"):
			active_perks_display.update_active_perks()
