extends Panel
class_name DynamicOptionsPanel

@export var max_height: int = 150  # Maximum height before scrolling
@export var button_height: int = 40  # Height of each button
@export var button_spacing: int = 5  # Spacing between buttons
@export var padding: int = 20  # Top and bottom padding

var vbox_container: VBoxContainer

func _ready():
	# Find the VBoxContainer
	vbox_container = get_node("ScrollContainer/VBoxContainer")
	if vbox_container:
		# Connect to child changes to update size
		vbox_container.child_entered_tree.connect(_update_size)
		vbox_container.child_exiting_tree.connect(_update_size)
		call_deferred("_update_size")

func _update_size():
	if not vbox_container:
		return
	
	# Count visible buttons
	var button_count = 0
	for child in vbox_container.get_children():
		if child is Button and child.visible:
			button_count += 1
	
	if button_count == 0:
		custom_minimum_size.y = 0
		visible = false
		return
	
	visible = true
	
	# Calculate needed height
	var needed_height = (button_count * button_height) + ((button_count - 1) * button_spacing) + padding
	
	# Clamp to max height
	var final_height = min(needed_height, max_height)
	custom_minimum_size.y = final_height
	
	print("Options panel: %d buttons, needed: %d, final: %d" % [button_count, needed_height, final_height])

func add_option(text: String, callback: Callable = Callable()) -> Button:
	if not vbox_container:
		return null
	
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, button_height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Apply bubble styling (you'll need to set these in the editor or via code)
	# button.theme_override_styles/normal = preload("res://path/to/style.tres")
	
	if callback.is_valid():
		button.pressed.connect(callback)
	
	vbox_container.add_child(button)
	_update_size()
	return button

func clear_options():
	if not vbox_container:
		return
	
	for child in vbox_container.get_children():
		child.queue_free()
	
	call_deferred("_update_size")
