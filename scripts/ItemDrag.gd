extends TextureRect
# Store the complete item data
var description_panel: PanelContainer 
var item_data: GameInfo.Item = null

func _ready():
	description_panel = get_tree().root.get_node("Game/Portrait/ItemDescription")
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	description_panel.visible = false


func _on_mouse_entered():
	if item_data:
		var mouse_pos = get_global_mouse_position()
		description_panel.show_description(item_data, mouse_pos)

func _on_mouse_exited():
	description_panel.hide_description()


func set_item_data(data: GameInfo.Item):
	item_data = data
	if data:
		texture = data.texture

func _get_drag_data(_at_position):
	if not item_data:
		return null
			
	# Create a preview for dragging
	var preview_texture = TextureRect.new()
	preview_texture.texture = texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.size = size
	preview_texture.position = -size / 2

	var preview = Control.new()
	preview.add_child(preview_texture)
	# Set high z-index so drag preview appears above all panels
	preview.z_index = 1000
	set_drag_preview(preview)

	# Create a drag data package with item and source reference
	var drag_package = {
		"item": item_data,
		"source_container": get_parent()
	}
	modulate.a = 0
	return drag_package

# Add this method to handle failed drops
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore full opacity - drag ended
		modulate.a = 1.0

func get_item_data() -> GameInfo.Item:
	return item_data
