extends TextureRect
# Store the complete item data
var description_panel: Panel 
var item_data: Dictionary = {}

func _ready():
	description_panel = get_tree().root.get_node("Game/Portrait/GameScene/ItemDescription")
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	description_panel.visible = false


func _on_mouse_entered():
	description_panel.show_description(item_data)

func _on_mouse_exited():
	description_panel.hide_description()


func set_item_data(data: Dictionary):
	item_data = data
	texture = data.get("texture", null)

func _get_drag_data(_at_position):
	if item_data.is_empty():
		return null
			
	# Create a preview for dragging
	var preview_texture = TextureRect.new()
	preview_texture.texture = texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.size = size
	preview_texture.position = -size / 2

	var preview = Control.new()
	preview.add_child(preview_texture)
	set_drag_preview(preview)

	# Store the source for restoration if needed
	var dragged_data = item_data.duplicate()
	dragged_data["_source_item"] = self  # Store reference to this item
	modulate.a = 0
	return dragged_data

# Add this method to handle failed drops
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore full opacity - drag ended
		modulate.a = 1.0


# Helper function to get item data
func get_item_data() -> Dictionary:
	return item_data
