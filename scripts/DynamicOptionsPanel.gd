extends Panel

# Simple book-style quest display
@export var quest_text_label: RichTextLabel  # Text (replaces, doeshern't accumulate)
@export var options_container: VBoxContainer  # Buttons below text

# Quest state
var current_quest_id: int = 0
var current_slide_number: int = 1

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
	"""Load a quest and display first slide"""
	if current_quest_id != quest_id:
		# Set quest title
		var quest_data = GameInfo.get_quest_data(quest_id)
		if quest_data:
			var title_label = get_node_or_null("QuestTitle")
			if title_label:
				title_label.text = quest_data.quest_name
	
	current_quest_id = quest_id
	current_slide_number = slide_number
	
	# Log this slide in the quest log
	GameInfo.log_quest_slide(quest_id, slide_number)
	
	var quest_slide = GameInfo.get_quest_slide(quest_id, slide_number)
	display_quest_slide(quest_slide)

func display_quest_slide(quest_slide: QuestSlide):
	"""Replace text with fade effect and show options"""
	# Fade out
	var tween = create_tween()
	tween.tween_property(quest_text_label, "modulate:a", 0.0, 0.2)
	await tween.finished
	
	# Replace text
	quest_text_label.text = quest_slide.text
	
	# Fade in
	tween = create_tween()
	tween.tween_property(quest_text_label, "modulate:a", 1.0, 0.3)
	
	# Update options
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

func _on_quest_option_pressed(option: QuestOption):
	"""Handle option click"""
	match option.option_type:
		QuestOption.OptionType.DIALOGUE:
			if option.slide_target > 0:
				load_quest(current_quest_id, option.slide_target)
		QuestOption.OptionType.COMBAT:
			# Random outcome for now
			var won = randf() > 0.5
			if won and option.on_win_slide > 0:
				load_quest(current_quest_id, option.on_win_slide)
			elif not won and option.on_lose_slide > 0:
				load_quest(current_quest_id, option.on_lose_slide)
		QuestOption.OptionType.END:
			_finish_quest()

func _finish_quest():
	"""End quest and return home"""
	# Mark quest as completed in quest log
	print("Finishing quest ID: ", current_quest_id)

	GameInfo.complete_quest(current_quest_id)
	GameInfo.current_player.traveling_destination = null
	GameInfo.current_player.traveling = 0
	current_quest_id = 0
	current_slide_number = 1
	
	# Call handle_quest_completed on active toggle panel through UIManager
	# This will hide the panel and navigate home
	if UIManager.instance:
		if UIManager.instance.portrait_ui.visible:
			UIManager.instance.portrait_ui.handle_quest_completed()
		elif UIManager.instance.wide_ui.visible:
			UIManager.instance.wide_ui.handle_quest_completed()
