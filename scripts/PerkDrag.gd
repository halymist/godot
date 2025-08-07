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
	set_drag_preview(preview)

	# Create a drag data package with perk and source reference
	var drag_package = {
		"type": "perk",
		"perk": perk_data,
		"source_container": get_parent()
	}
	modulate.a = 0  # Make original completely invisible during drag
	return drag_package

# Add this method to handle failed drops
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore full opacity - drag ended
		modulate.a = 1.0
		print("Drag ended for perk: ", perk_data.perk_name if perk_data else "unknown")

func get_perk_data() -> GameInfo.Perk:
	return perk_data
