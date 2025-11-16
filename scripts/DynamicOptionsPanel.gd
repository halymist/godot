extends Panel

# Simple book-style quest display
@export var quest_text_label: RichTextLabel  # Accumulates all text
@export var options_container: VBoxContainer  # Buttons below text

# Quest state
var current_quest_id: int = 0
var current_slide_number: int = 1
var quest_history: String = ""  # All accumulated text

# Reference to portrait for navigation
@export var portrait: Control

# Quest signals
signal quest_arrived()

func _ready():
	quest_arrived.connect(_on_quest_arrived)

func _on_quest_arrived():
	"""Quest arrival from travel"""
	var quest_id = GameInfo.current_player.traveling_destination if GameInfo.current_player else null
	if quest_id:
		load_quest(quest_id, 1)

func load_quest(quest_id: int, slide_number: int = 1):
	"""Load a quest and start from slide 1"""
	if current_quest_id != quest_id:
		quest_history = ""  # Reset history for new quest
	
	current_quest_id = quest_id
	current_slide_number = slide_number
	
	var quest_slide = GameInfo.get_quest_slide(quest_id, slide_number)
	display_quest_slide(quest_slide)

func display_quest_slide(quest_slide: GameInfo.QuestSlide):
	"""Add text to page and show options"""
	# Append text to history
	if quest_history != "":
		quest_history += "\n\n"
	quest_history += quest_slide.text
	
	# Update display
	quest_text_label.text = quest_history
	
	# Clear old options and add new ones
	clear_options()
	for option in quest_slide.options:
		add_option(option.text, _on_quest_option_pressed.bind(option))

func add_option(text: String, callback: Callable) -> Button:
	"""Add a button to options"""
	if not options_container:
		return null
	
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_FILL
	
	if callback.is_valid():
		button.pressed.connect(callback)
	
	options_container.add_child(button)
	return button

func clear_options():
	"""Remove all option buttons"""
	if not options_container:
		return
	
	for child in options_container.get_children():
		child.queue_free()

func _on_quest_option_pressed(option: GameInfo.QuestOption):
	"""Handle option click"""
	match option.type:
		"dialogue":
			if option.slide_target > 0:
				load_quest(current_quest_id, option.slide_target)
		"combat":
			# Random outcome for now
			var won = randf() > 0.5
			if won and option.on_win_slide > 0:
				load_quest(current_quest_id, option.on_win_slide)
			elif not won and option.on_loose_slide > 0:
				load_quest(current_quest_id, option.on_loose_slide)
		"end":
			_finish_quest()

func _finish_quest():
	"""End quest and return home"""
	GameInfo.current_player.traveling_destination = null
	GameInfo.current_player.traveling = null
	current_quest_id = 0
	current_slide_number = 1
	quest_history = ""
	portrait.show_panel(portrait.home_panel)
