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
	
	# 7. Update button max widths to 80% of quest panel width
	_update_button_widths(total_width * 0.8)
	
	print("=== Layout Complete ===")

func _update_button_widths(max_width: float):
	if not options_vbox:
		return
	
	for child in options_vbox.get_children():
		if child is Button:
			# Set custom max size to 80% of quest panel width
			child.custom_minimum_size.x = min(300, max_width)
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			child.clip_contents = true

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
	button.custom_minimum_size = Vector2(300, button_height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	
	# Set max width to 80% of quest panel width
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.clip_contents = true
	
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

# Quest Slide System
var current_quest_id: int = 0
var current_slide_number: int = 1

func load_quest(quest_id: int, slide_number: int = 1):
	"""Load and display a quest slide from GameInfo"""
	current_quest_id = quest_id
	current_slide_number = slide_number
	
	var quest_slide = GameInfo.get_quest_slide(quest_id, slide_number)
	if quest_slide:
		display_quest_slide(quest_slide)
	else:
		print("Failed to load quest slide: quest_id=", quest_id, " slide=", slide_number)

func display_quest_slide(quest_slide: GameInfo.QuestSlide):
	"""Display the quest slide text and create option buttons"""
	# Set the quest text
	if quest_text_panel:
		var quest_label = quest_text_panel.get_node_or_null("Label")
		if not quest_label:
			quest_label = Label.new()
			quest_label.name = "Label"
			quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			quest_text_panel.add_child(quest_label)
		quest_label.text = quest_slide.text
	
	# Clear existing options and create new ones
	clear_options()
	
	for option in quest_slide.options:
		add_option(option.text, _on_quest_option_pressed.bind(option))
	
	call_deferred("_update_layout")
	print("Displayed quest slide ", quest_slide.slide, ": ", quest_slide.text)

func _on_quest_option_pressed(option: GameInfo.QuestOption):
	"""Handle quest option selection"""
	print("Selected option: ", option.text)
	
	match option.type:
		"dialogue":
			# Navigate to target slide
			if option.slide_target > 0:
				load_quest(current_quest_id, option.slide_target)
		"combat":
			# Handle combat option
			print("Combat option selected - Enemy: ", option.enemy)
			# TODO: Implement combat system integration
			# For now, just show win/lose options based on random outcome
			var won_combat = randf() > 0.5  # Random outcome for demo
			if won_combat and option.on_win_slide > 0:
				load_quest(current_quest_id, option.on_win_slide)
			elif not won_combat and option.on_loose_slide > 0:
				load_quest(current_quest_id, option.on_loose_slide)
		_:
			print("Unknown option type: ", option.type)
