extends Panel

var perk_data: GameInfo.Perk = null

func set_perk_data(data: GameInfo.Perk):
	perk_data = data
	if data:
		# Update the UI elements
		var label = get_node("Label")
		label.text = data.perk_name + "\n" + data.description
		
		var texture_rect = get_node("AspectRatioContainer/TextureRect")
		texture_rect.texture = data.texture

func _get_drag_data(_at_position):
	if not perk_data:
		return null
	
	# Immediately set mouse filter to ignore to prevent blocking
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set all other perks to ignore mouse to prevent drop conflicts
	_set_all_perks_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	
	# Create a preview for dragging
	var preview = duplicate()
	preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ensure preview doesn't block
	
	# Center the preview on the mouse position by using the current node's size
	var current_size = size
	var offset = Vector2(0, current_size.y / 2)
	
	# Create a container to hold the preview with proper offset
	var preview_container = Control.new()
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Container also ignores
	preview_container.size = current_size  # Set container size
	preview_container.add_child(preview)
	preview.position = -offset
	
	set_drag_preview(preview_container)

	# Create a drag data package with perk and source reference
	var drag_package = {
		"type": "perk",
		"perk": perk_data,
		"source_container": get_parent(),
		"source_node": self  # Include reference to the dragged node
	}
	
	# Store original size for restoration and shrink to height 0 instantly
	var original_size = custom_minimum_size if custom_minimum_size != Vector2.ZERO else size
	set_meta("original_size", original_size)
	print("Shrinking perk from size: ", original_size, " to height 0")
	custom_minimum_size = Vector2(original_size.x, 0.0)  # Instant shrink, no animation
	
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
