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
			
	# Create a preview for dragging
	var preview = duplicate()
	preview.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent
	
	# Center the preview on the mouse position by using the current node's size
	var current_size = size
	if current_size == Vector2.ZERO:
		# Fallback to a reasonable default size if size isn't calculated yet
		current_size = Vector2(70, 70)  # Typical perk size
	
	# Calculate offset to center the preview on mouse cursor
	var offset = Vector2(current_size.x / 2, current_size.y / 2)
	
	# Create a container to hold the preview with proper offset
	var preview_container = Control.new()
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
	
	# Hide the original node by making it take no space
	visible = false
	return drag_package

# Add this method to handle failed drops
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore visibility - drag ended
		visible = true
		print("Drag ended for perk: ", perk_data.perk_name if perk_data else "unknown")

func get_perk_data() -> GameInfo.Perk:
	return perk_data
