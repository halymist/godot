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
	
	# Hide the original node by making it semi-transparent instead of invisible
	modulate.a = 0.3
	return drag_package

# Add this method to handle failed drops
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore mouse filter and visibility
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 1.0
		visible = true

func get_perk_data() -> GameInfo.Perk:
	return perk_data
