extends Panel

# Panel references
@export var status_panel: Panel
@export var scene_panel: AspectRatioContainer  
@export var quest_text_panel: Panel
@export var quest_text_label: RichTextLabel  # Changed to RichTextLabel
@export var options_panel: Panel

# TogglePanel reference for navigation
@export var portrait: Control  # Reference to the Portrait/TogglePanel

# Settings
@export var status_height: int = 60
@export var scene_aspect_ratio: float = 1.333  # 4:3 aspect ratio
@export var min_bottom_height: int = 100
@export var max_options_height: int = 150
@export var button_height: int = 40
@export var button_spacing: int = 5
@export var options_padding: int = 20

@export var options_vbox: VBoxContainer

# Quest system variables
var current_quest_id: int = 0
var current_slide_number: int = 1

# Quest signals
signal quest_arrived()

func _ready():
	options_vbox.child_entered_tree.connect(_update_layout)
	options_vbox.child_exiting_tree.connect(_update_layout)
	resized.connect(_update_layout)
	
	# Connect quest arrival signal to handler
	quest_arrived.connect(_on_quest_arrived)
	

func _on_quest_arrived():
	"""Internal signal handler for quest arrival"""
	print("=== QUEST ARRIVED SIGNAL RECEIVED ===")
	
	# Get quest ID from GameInfo
	var quest_id = GameInfo.current_player.traveling_destination if GameInfo.current_player else null
	
	if quest_id:
		print("Loading quest slides for quest ID: ", quest_id)
		load_quest(quest_id, 1)
	else:
		print("✗ No traveling destination found!")

func _update_layout():
	if not status_panel or not scene_panel or not quest_text_panel or not options_panel:
		return
	
	var total_height = size.y
	var total_width = size.x
		
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

	# 3. Calculate remaining height for bottom panels
	var remaining_height = total_height - status_height - scene_height
	var bottom_y = scene_y + scene_height
	
	
	# 4. Calculate options height based on content
	var options_height = _calculate_options_height()
	options_height = min(options_height, max_options_height)
	options_height = min(options_height, remaining_height - 50) # Leave some space for text
	
	# 5. Position quest text panel
	var text_height = remaining_height - options_height
	quest_text_panel.position = Vector2(0, bottom_y)
	quest_text_panel.size = Vector2(total_width, text_height)
	
	# 6. Position options panel
	options_panel.position = Vector2(0, bottom_y + text_height)
	options_panel.size = Vector2(total_width, options_height)
	
	# 7. Update button max widths to 80% of quest panel width
	_update_button_widths(total_width * 0.8)
	

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
	
	
	if callback.is_valid():
		button.pressed.connect(callback)
	
	options_vbox.add_child(button)
	return button

func clear_options():
	if not options_vbox:
		return
	
	for child in options_vbox.get_children():
		child.queue_free()
	

func set_scene_aspect_ratio(ratio: float):
	scene_aspect_ratio = ratio
	_update_layout()

# Quest Slide System
func load_quest(quest_id: int, slide_number: int = 1):
	"""Load and display a quest slide from GameInfo"""
	print("=== LOADING QUEST ===")
	print("Quest ID: ", quest_id)
	print("Slide number: ", slide_number)
	
	current_quest_id = quest_id
	current_slide_number = slide_number
	var quest_slide = GameInfo.get_quest_slide(quest_id, slide_number)
	print("get_quest_slide returned: ", quest_slide != null)
	display_quest_slide(quest_slide)

func display_quest_slide(quest_slide: GameInfo.QuestSlide):
	"""Display the quest slide text and create option buttons"""
	print("=== DISPLAYING QUEST SLIDE ===")
	print("Quest slide object: ", quest_slide)
	print("Quest text: '", quest_slide.text, "'")
	print("Options count: ", quest_slide.options.size())

	clear_options()
	
	print("Creating ", quest_slide.options.size(), " option buttons...")
	for i in range(quest_slide.options.size()):
		var option = quest_slide.options[i]
		print("Option ", i + 1, ": '", option.text, "'")
		add_option(option.text, _on_quest_option_pressed.bind(option))
	
	# Force layout update
	print("Forcing layout update...")
	call_deferred("_update_layout")
	
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
		"end":
			print("Quest ended! Returning to home screen...")
			_finish_quest()
		_:
			print("Unknown option type: ", option.type)

func _finish_quest():
	"""Complete the current quest and return to home screen"""
	print("=== FINISHING QUEST ===")
	print("Quest ID: ", current_quest_id)
	
	# Clear quest state
	GameInfo.current_player.traveling_destination = null
	GameInfo.current_player.traveling = null
	
	# Reset quest variables
	current_quest_id = 0
	current_slide_number = 1

	portrait.show_panel(portrait.home_panel)
	print("Quest finished and returned to home screen")
