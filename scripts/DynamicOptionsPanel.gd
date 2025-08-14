extends Panel
class_name QuestUIManager

# Panel references
@export var status_panel: Panel
@export var scene_panel: AspectRatioContainer  
@export var quest_text_panel: Panel
@export var quest_text_label: RichTextLabel  # Changed to RichTextLabel
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

# Quest system variables
var current_quest_id: int = 0
var current_slide_number: int = 1

# Quest signals
signal quest_arrived(quest_id: int)
signal quest_slide_changed(quest_id: int, slide_number: int)

func _ready():
	print("=== DynamicOptionsPanel._ready() ===")
	# Get panel references if not set
	if not status_panel:
		status_panel = get_node_or_null("StatusPanel")
	if not scene_panel:
		scene_panel = get_node_or_null("ScenePanel") 
	if not quest_text_panel:
		quest_text_panel = get_node_or_null("BottomPanel/QuestTextPanel")
		print("quest_text_panel found: ", quest_text_panel != null)
	if not quest_text_label:
		quest_text_label = get_node_or_null("BottomPanel/QuestTextPanel/RichTextLabel")
		print("quest_text_label found: ", quest_text_label != null)
	if not options_panel:
		options_panel = get_node_or_null("BottomPanel/OptionsPanel")
		print("options_panel found: ", options_panel != null)
	
	# Find options VBoxContainer
	if options_panel:
		options_vbox = options_panel.get_node_or_null("ScrollContainer/VBoxContainer")
		print("options_vbox found: ", options_vbox != null)
		if options_vbox:
			options_vbox.child_entered_tree.connect(_update_layout)
			options_vbox.child_exiting_tree.connect(_update_layout)
	
	# Connect to resize
	resized.connect(_update_layout)
	
	# Connect quest arrival signal to handler
	quest_arrived.connect(_on_quest_arrived)
	
	call_deferred("_update_layout")
	print("DynamicOptionsPanel ready!")

func trigger_quest_arrival(quest_id: int):
	"""External function to trigger quest arrival"""
	print("=== TRIGGERING QUEST ARRIVAL ===")
	print("Quest ID: ", quest_id)
	quest_arrived.emit(quest_id)

func _on_quest_arrived(quest_id: int):
	"""Internal signal handler for quest arrival"""
	print("=== QUEST ARRIVED SIGNAL RECEIVED ===")
	print("Quest ID: ", quest_id)
	print("Player traveling_destination: ", GameInfo.current_player.traveling_destination if GameInfo.current_player else "No player")
	print("Available quest IDs in GameInfo: ", GameInfo.quest_slides.keys() if GameInfo.quest_slides else [])
	
	# Verify this is the right quest
	if GameInfo.current_player and GameInfo.current_player.traveling_destination == quest_id:
		print("✓ Quest arrival confirmed! Loading quest slides...")
		load_quest(quest_id, 1)
	else:
		print("✗ Player not traveling to this quest!")
		if GameInfo.current_player:
			print("  Expected quest: ", quest_id)
			print("  Player traveling to: ", GameInfo.current_player.traveling_destination)
		else:
			print("  No current player found!")

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
func load_quest(quest_id: int, slide_number: int = 1):
	"""Load and display a quest slide from GameInfo"""
	print("=== LOADING QUEST ===")
	print("Quest ID: ", quest_id)
	print("Slide number: ", slide_number)
	
	current_quest_id = quest_id
	current_slide_number = slide_number
	
	print("GameInfo.quest_slides exists: ", GameInfo.quest_slides != null)
	if GameInfo.quest_slides:
		print("Available quest IDs: ", GameInfo.quest_slides.keys())
		print("Quest ", quest_id, " exists: ", GameInfo.quest_slides.has(quest_id))
		
		if GameInfo.quest_slides.has(quest_id):
			var quest_data = GameInfo.quest_slides[quest_id]
			print("Quest data type: ", typeof(quest_data))
			print("Quest slides count: ", quest_data.size() if quest_data else 0)
			
			if quest_data and slide_number <= quest_data.size():
				print("Slide ", slide_number, " exists in quest data")
			else:
				print("Slide ", slide_number, " does NOT exist! Max slides: ", quest_data.size() if quest_data else 0)
	
	var quest_slide = GameInfo.get_quest_slide(quest_id, slide_number)
	print("get_quest_slide returned: ", quest_slide != null)
	
	if quest_slide:
		print("Quest slide text: '", quest_slide.text, "'")
		print("Quest slide options count: ", quest_slide.options.size())
		display_quest_slide(quest_slide)
	else:
		print("✗ Failed to load quest slide: quest_id=", quest_id, " slide=", slide_number)

func display_quest_slide(quest_slide: GameInfo.QuestSlide):
	"""Display the quest slide text and create option buttons"""
	print("=== DISPLAYING QUEST SLIDE ===")
	print("Quest slide object: ", quest_slide)
	print("Quest text: '", quest_slide.text, "'")
	print("Options count: ", quest_slide.options.size())
	
	# Set the quest text
	print("quest_text_label exists: ", quest_text_label != null)
	if quest_text_label:
		print("quest_text_label node path: ", quest_text_label.get_path())
		print("quest_text_label visible: ", quest_text_label.visible)
		
		print("Setting text directly on RichTextLabel...")
		quest_text_label.text = quest_slide.text
		print("RichTextLabel text set to: '", quest_text_label.text, "'")
		print("RichTextLabel visible: ", quest_text_label.visible)
		print("RichTextLabel size: ", quest_text_label.size)
	else:
		print("✗ quest_text_label is null!")
	
	# Clear existing options and create new ones
	print("Clearing existing options...")
	clear_options()
	
	print("Creating ", quest_slide.options.size(), " option buttons...")
	for i in range(quest_slide.options.size()):
		var option = quest_slide.options[i]
		print("Option ", i + 1, ": '", option.text, "'")
		add_option(option.text, _on_quest_option_pressed.bind(option))
	
	call_deferred("_update_layout")
	
	# Emit signal for quest slide change
	quest_slide_changed.emit(current_quest_id, current_slide_number)
	
	print("✓ Quest slide display complete. Slide ", quest_slide.slide, " text: '", quest_slide.text, "'")

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
