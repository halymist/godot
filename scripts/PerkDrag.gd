extends Panel

var perk_data: GameInfo.Perk = null

func set_perk_data(data: GameInfo.Perk):
	perk_data = data
	if data:
		# Update the UI elements
		var label = get_node("Label")
		
		# Build label text with perk name and effects
		var label_text = data.perk_name
		
		# Add effect 1 if it exists
		if data.effect1_description != "":
			var effect1_text = data.effect1_description
			if data.factor1 != 0.0:
				effect1_text += " " + str(int(data.factor1))
			label_text += "\n" + effect1_text
		
		# Add effect 2 if it exists
		if data.effect2_description != "":
			var effect2_text = data.effect2_description
			if data.factor2 != 0.0:
				effect2_text += " " + str(int(data.factor2))
			label_text += "\n" + effect2_text
		
		label.text = label_text
		
		var texture_rect = get_node("AspectRatioContainer/TextureRect")
		texture_rect.texture = data.texture
		
		# Apply dynamic color styling based on perk state
		_update_perk_colors(data)

func _get_drag_data(_at_position):
	if not perk_data:
		return null

	# Immediately set mouse filter to ignore to prevent blocking input
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set all other perks to ignore mouse to prevent drop conflicts
	_set_all_perks_mouse_filter(Control.MOUSE_FILTER_IGNORE)

	# Create a preview for dragging
	var preview = duplicate()
	preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent preview
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Preview ignores mouse
	
	# Ensure the preview has the correct texture and styling
	if perk_data and perk_data.texture:
		var preview_texture_rect = preview.get_node("AspectRatioContainer/TextureRect")
		if preview_texture_rect:
			preview_texture_rect.texture = perk_data.texture
	
	# Apply special preview styling (semi-transparent look)
	_apply_preview_styling(preview)

	# Center the preview on the mouse position using current node's size
	var current_size = size
	var offset = Vector2(0, current_size.y / 2)

	# Create a container to hold the preview with proper offset
	var preview_container = Control.new()
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Container ignores mouse too
	preview_container.size = current_size
	preview_container.add_child(preview)
	preview.position = -offset

	set_drag_preview(preview_container)

	# Create a drag data package with perk data and source references
	var drag_package = {
		"type": "perk",
		"perk": perk_data,
		"source_container": get_parent(),
		"source_node": self
	}

	# Store original size for restoration
	var original_size = custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
	set_meta("original_size", original_size)

	# Shrink the perk instantly to height 0 to hide from layout
	custom_minimum_size = Vector2(original_size.x, 0)

	# Also hide the original node completely to avoid layout forcing size
	visible = false

	return drag_package


# Add this method to handle failed drops
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore mouse filter and visibility
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 1.0
		visible = true
		
		# Restore all perks mouse filter
		_set_all_perks_mouse_filter(Control.MOUSE_FILTER_STOP)
		
		# Restore original height instantly if drag failed (no successful drop)
		if has_meta("original_size"):
			var original_size = get_meta("original_size")
			print("Restoring perk to original size: ", original_size)
			custom_minimum_size = Vector2(original_size.x, original_size.y)  # Instant restore, no animation
			remove_meta("original_size")

func get_perk_data() -> GameInfo.Perk:
	return perk_data

func _update_perk_colors(perk: GameInfo.Perk):
	# Get the existing panel style and just update colors
	var current_style = get_theme_stylebox("panel")
	if current_style is StyleBoxFlat:
		var style = current_style.duplicate()
		
		# Update colors based on perk state
		if perk.active:
			# Active perks get warm colors
			style.bg_color = Color(0.6, 0.2, 0.1, 0.95)  # Deep red
			style.border_color = Color(1.0, 0.6, 0.3, 1.0)  # Orange border
		else:
			# Inactive perks get cool colors (default from scene)
			style.bg_color = Color(0.1, 0.2, 0.6, 0.95)  # Deep blue
			style.border_color = Color(0.3, 0.6, 1.0, 1.0)  # Light blue border
		
		add_theme_stylebox_override("panel", style)

func _apply_preview_styling(preview_node: Control):
	# Make the preview more transparent and add a glow effect
	var preview_style = StyleBoxFlat.new()
	
	# Base it on the current perk's colors but more transparent
	if perk_data.active:
		preview_style.bg_color = Color(0.6, 0.2, 0.1, 0.6)  # More transparent red
		preview_style.border_color = Color(1.0, 0.6, 0.3, 0.8)  # Semi-transparent orange
	else:
		preview_style.bg_color = Color(0.1, 0.2, 0.6, 0.6)  # More transparent blue
		preview_style.border_color = Color(0.3, 0.6, 1.0, 0.8)  # Semi-transparent blue
	
	# Add glow effect for the preview
	preview_style.shadow_color = Color(1, 1, 1, 0.4)  # White glow
	preview_style.shadow_size = 8
	preview_style.shadow_offset = Vector2(0, 0)
	
	# Keep the rounded corners
	preview_style.corner_radius_top_left = 10
	preview_style.corner_radius_top_right = 10
	preview_style.corner_radius_bottom_left = 10
	preview_style.corner_radius_bottom_right = 10
	
	# Border
	preview_style.border_width_left = 2
	preview_style.border_width_right = 2
	preview_style.border_width_top = 2
	preview_style.border_width_bottom = 2
	
	preview_node.add_theme_stylebox_override("panel", preview_style)

func _set_all_perks_mouse_filter(filter_mode: int):
	# Find all perk nodes in all panels and set their mouse filter
	var game_scene = get_tree().root.get_node("Game/Portrait/GameScene")
	if not game_scene:
		return
	
	# Find all perk panels (both active and inactive)
	var perk_panels = []
	_find_perk_panels_recursive(game_scene, perk_panels)
	
	for panel in perk_panels:
		for child in panel.get_children():
			if child.has_method("get_perk_data"):  # This is a perk node
				child.mouse_filter = filter_mode

func _find_perk_panels_recursive(node: Node, panels: Array):
	if node.has_method("place_perk_in_panel"):  # This is a PerkPanel
		panels.append(node)
	
	for child in node.get_children():
		_find_perk_panels_recursive(child, panels)
