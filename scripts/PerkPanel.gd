extends Control

@export var panel_type: String = "Active" # "Active" or "Inactive"
@export var perk_scene: PackedScene
var slot_filter: int = 0 # Which perk slot this active panel is showing


# Variables for drag feedback
var drag_placeholder: Control = null
var is_dragging_over: bool = false

func _can_drop_data(pos, data):
	# Check if data is valid drag package
	if not (data is Dictionary and data.has("perk") and data["perk"] is GameInfo.Perk):
		return false
	
	# For inactive panel, always show placeholder and allow drop
	if panel_type == "Inactive":
		if not is_dragging_over:
			is_dragging_over = true
			_create_placeholder()
		_update_placeholder_position(pos)
		return true
	
	# For active panel, we accept any perk and create placeholder
	if panel_type == "Active":
		if not is_dragging_over:
			is_dragging_over = true
			_create_placeholder()
			add_child(drag_placeholder)
			move_child(drag_placeholder, 0)  # Always at the top for active panels
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
	
	# Restore all perks mouse filter since drag is ending successfully
	_restore_all_perks_mouse_filter()
	
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
		
		# The dragged node was already shrunk to height 0 during drag start
		# Clear its restoration metadata and queue it for removal
		var source_node = data.get("source_node", null)
		if source_node:
			source_node.remove_meta("original_size")
			source_node.queue_free()
	else:
		print("Active panel is empty, moving perk...")
		# Just place the perk in active panel
		place_perk_in_panel(perk)
		
		# The dragged node was already shrunk to height 0 during drag start
		# Clear its restoration metadata and queue it for removal
		var source_node = data.get("source_node", null)
		if source_node:
			source_node.remove_meta("original_size")
			source_node.queue_free()

func _handle_inactive_drop(perk: GameInfo.Perk, _source_container: Control, data: Dictionary):
	print("Moving perk to inactive panel")
	
	# Update perk data to be inactive
	perk.active = false
	
	# Place perk in inactive panel
	place_perk_in_panel(perk)
	
	# The dragged node was already shrunk to height 0 during drag start
	# Clear its restoration metadata and queue it for removal
	var source_node = data.get("source_node", null)
	if source_node:
		source_node.remove_meta("original_size")
		source_node.queue_free()

func _handle_reorder(_pos: Vector2, data):
	# Get the dragged perk
	var perk_data = data["perk"]
	var dragged_node = data.get("source_node", null)
	
	# Find the best insertion point based on placeholder position
	var placeholder_index = drag_placeholder.get_index() if drag_placeholder else get_child_count()
	
	# Create new perk at the placeholder position
	var new_perk = perk_scene.instantiate()
	new_perk.set_perk_data(perk_data)
	add_child(new_perk)
	move_child(new_perk, placeholder_index)
	
	# Clear the restoration metadata since we successfully placed it
	if dragged_node:
		dragged_node.remove_meta("original_size")
		dragged_node.queue_free()

func place_perk_in_panel(perk_data: GameInfo.Perk):
	print("Placing perk '", perk_data.perk_name, "' in panel: ", self.name)
	
	# Create new perk instance
	var new_perk = perk_scene.instantiate()
	
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
	
	# Ensure placeholder is added to the panel
	if drag_placeholder.get_parent() != self:
		add_child(drag_placeholder)
		# Animate placeholder height when first added
		var target_height = 70.0  # Standard perk height
		var existing_children = get_children()
		for child in existing_children:
			if child != drag_placeholder and child.has_method("get_rect"):
				target_height = child.get_rect().size.y
				break
		_animate_placeholder_height(target_height * 0.8)
	
	# Get all non-placeholder children
	var logical_children = []
	for child in get_children():
		if child != drag_placeholder:
			logical_children.append(child)
	
	# Find insertion index based on Y position
	var insert_index = logical_children.size()  # Default to end
	
	for i in range(logical_children.size()):
		var child = logical_children[i]
		var child_rect = child.get_rect()
		var child_global_pos = child.global_position
		var child_center_y = child_global_pos.y + child_rect.size.y * 0.5
		
		# Convert pos to global coordinates for comparison
		var global_pos = global_position + pos
		
		if global_pos.y < child_center_y:
			insert_index = i
			break
	
	# Calculate the actual index considering the placeholder
	var target_index = insert_index
	var current_placeholder_index = drag_placeholder.get_index()
	
	# Only move if the position has changed
	if current_placeholder_index != target_index:
		move_child(drag_placeholder, target_index)

func _animate_placeholder_height(target_height: float):
	if not drag_placeholder:
		return
		
	# Simple tween animation for placeholder height
	var tween = create_tween()
	tween.tween_property(drag_placeholder, "custom_minimum_size:y", target_height, 0.15)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)


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

func _restore_all_perks_mouse_filter():
	# Find all perk nodes in all panels and restore their mouse filter
	var game_scene = get_tree().root.get_node("Game/Portrait/GameScene")
	if not game_scene:
		return
	
	# Find all perk panels (both active and inactive)
	var perk_panels = []
	_find_perk_panels_recursive(game_scene, perk_panels)
	
	for panel in perk_panels:
		for child in panel.get_children():
			if child.has_method("get_perk_data"):  # This is a perk node
				child.mouse_filter = Control.MOUSE_FILTER_STOP

func _find_perk_panels_recursive(node: Node, panels: Array):
	if node.has_method("place_perk_in_panel"):  # This is a PerkPanel
		panels.append(node)
	
	for child in node.get_children():
		_find_perk_panels_recursive(child, panels)
