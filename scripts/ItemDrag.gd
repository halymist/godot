extends TextureRect
# Store the complete item data
var item_data: GameInfo.Item = null

# Double-click detection
var last_click_time: float = 0.0
const DOUBLE_CLICK_TIME: float = 0.3  # 300ms window for double-click

func _ready():
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	connect("gui_input", Callable(self, "_on_gui_input"))


func _on_mouse_entered():
	if item_data:
		# Get the parent slot to determine positioning
		var parent_slot = get_parent()
		TooltipManager.show_tooltip(item_data, parent_slot)

func _on_mouse_exited():
	TooltipManager.hide_tooltip()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_click_time < DOUBLE_CLICK_TIME:
			# Double-click detected
			_handle_double_click()
			last_click_time = 0.0  # Reset to prevent triple-click
		else:
			last_click_time = current_time

func _handle_double_click():
	if not item_data:
		return
	
	# Delegate to parent slot's unified handler
	var parent_slot = get_parent()
	if parent_slot and parent_slot.has_method("handle_double_click"):
		parent_slot.handle_double_click(item_data)



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
