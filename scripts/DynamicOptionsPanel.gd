extends Panel
class_name QuestUIManager

# Panel references
@export var status_panel: Panel
@export var scene_panel: AspectRatioContainer  
@export var quest_text_panel: Panel
@export var options_panel: Panel

# Settings
@export var status_height: int = 60
@export var scene_aspect_ratio: float = 1.333  # 4:3 aspect ratio
@export var min_bottom_height: int = 100
@export var max_options_height: int = 150
@export var button_height: int = 40
@export var button_spacing: int = 5
@export var options_padding: int = 20

var options_vbox: VBoxContainer

func _ready():
	# Get panel references if not set
	if not status_panel:
		status_panel = get_node_or_null("StatusPanel")
	if not scene_panel:
		scene_panel = get_node_or_null("ScenePanel") 
	if not quest_text_panel:
		quest_text_panel = get_node_or_null("BottomPanel/QuestTextPanel")
	if not options_panel:
		options_panel = get_node_or_null("BottomPanel/OptionsPanel")
	
	# Find options VBoxContainer
	if options_panel:
		options_vbox = options_panel.get_node_or_null("ScrollContainer/VBoxContainer")
		if options_vbox:
			options_vbox.child_entered_tree.connect(_update_layout)
			options_vbox.child_exiting_tree.connect(_update_layout)
	
	# Connect to resize
	resized.connect(_update_layout)
	call_deferred("_update_layout")

func _update_layout():
	if not status_panel or not scene_panel or not quest_text_panel or not options_panel:
		return
	
	var total_height = size.y
	var total_width = size.x
	
	print("=== Quest UI Layout Update ===")
	print("Total size: %s" % size)
	
	# 1. Position status panel at top
	status_panel.position = Vector2.ZERO
	status_panel.size = Vector2(total_width, status_height)
	print("Status panel: pos=%s size=%s" % [status_panel.position, status_panel.size])
	
	# 2. Calculate scene panel size (4:3 aspect ratio, full width)
	var scene_width = total_width
	var scene_height = scene_width / scene_aspect_ratio
	var scene_y = status_height
	
	scene_panel.position = Vector2(0, scene_y)
	scene_panel.size = Vector2(scene_width, scene_height)
	print("Scene panel: pos=%s size=%s" % [scene_panel.position, scene_panel.size])
	
	# 3. Calculate remaining height for bottom panels
	var remaining_height = total_height - status_height - scene_height
	var bottom_y = scene_y + scene_height
	
	print("Remaining height for bottom: %d" % remaining_height)
	
	# 4. Calculate options height based on content
	var options_height = _calculate_options_height()
	options_height = min(options_height, max_options_height)
	options_height = min(options_height, remaining_height - 50) # Leave some space for text
	
	# 5. Position quest text panel
	var text_height = remaining_height - options_height
	quest_text_panel.position = Vector2(0, bottom_y)
	quest_text_panel.size = Vector2(total_width, text_height)
	print("Text panel: pos=%s size=%s" % [quest_text_panel.position, quest_text_panel.size])
	
	# 6. Position options panel
	options_panel.position = Vector2(0, bottom_y + text_height)
	options_panel.size = Vector2(total_width, options_height)
	print("Options panel: pos=%s size=%s" % [options_panel.position, options_panel.size])
	
	print("=== Layout Complete ===")

func _calculate_options_height() -> int:
	if not options_vbox:
		return min_bottom_height
	
	# Count visible buttons
	var button_count = 0
	for child in options_vbox.get_children():
		if child is Button and child.visible:
			button_count += 1
	
	if button_count == 0:
		return 0
	
	# Calculate needed height
	var needed_height = (button_count * button_height) + ((button_count - 1) * button_spacing) + options_padding
	return needed_height

func add_option(text: String, callback: Callable = Callable()) -> Button:
	if not options_vbox:
		return null
	
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, button_height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Apply bubble styling - you'll need to set the style resource
	# button.theme_override_styles/normal = preload("res://path/to/bubble_style.tres")
	
	if callback.is_valid():
		button.pressed.connect(callback)
	
	options_vbox.add_child(button)
	call_deferred("_update_layout")
	return button

func clear_options():
	if not options_vbox:
		return
	
	for child in options_vbox.get_children():
		child.queue_free()
	
	call_deferred("_update_layout")

func set_scene_aspect_ratio(ratio: float):
	scene_aspect_ratio = ratio
	_update_layout()
