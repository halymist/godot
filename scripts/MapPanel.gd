extends Panel

@export var quest_name_label: Label
@export var travel_text_label: Label
@export var travel_progress: TextureProgressBar
@export var travel_time_label: Label
@export var skip_button: Button
@export var enter_dungeon_button: Button
@export var background: TextureRect

var is_skipping: bool = false
var skip_start_time: float = 0.0
var original_travel_end: float = 0.0

# Travel info set when quest is accepted
var travel_text: String
var travel_duration: float

func _ready():
	skip_button.pressed.connect(_on_skip_button_pressed)
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_pressed)
	GameInfo.character_changed.connect(_on_character_changed)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)  # Only process when traveling
	

func _on_character_changed():
	# Update UI state when character changes
	refresh_travel_state()

func _on_visibility_changed():
	# Refresh state when panel becomes visible
	if visible:
		refresh_travel_state()



func start_travel(quest_travel_text: String, duration_seconds: int, quest_id: int = 0):
	"""Start traveling with the given text and duration (0 for VIP = instant)"""
	travel_text = quest_travel_text
	travel_duration = float(duration_seconds)  # Duration is already in seconds (0 for VIP)
	print("Started travel: '", travel_text, "' for ", duration_seconds, " seconds (VIP=instant)" if duration_seconds == 0 else " seconds")
	print("Travel duration in seconds: ", travel_duration)
	set_process(true)  # Enable frame-by-frame updates for smooth progress
	
	# Apply quest background texture and set quest name
	var quest_data = GameInfo.quests_db.get_quest_by_id(quest_id) if GameInfo.quests_db else null
	if quest_data:
		if quest_data.background_texture:
			background.texture = quest_data.background_texture
			print("Applied quest background texture")
		quest_name_label.text = quest_data.quest_name
	
	refresh_travel_state()
	print("Travel UI update triggered")

func refresh_travel_state():
	"""Update UI state based on current travel status - call this when state changes"""
	var current_player = GameInfo.current_player
	
	# Check if player has a quest destination (VIP instant travel or timer-based)
	if current_player.traveling_destination != null and current_player.traveling == 0:
		# VIP instant travel - show Go Quest button immediately
		travel_text_label.text = travel_text
		travel_progress.value = travel_progress.max_value
		travel_time_label.text = ""
		skip_button.visible = false
		enter_dungeon_button.visible = true
		enter_dungeon_button.text = "Go Quest"
		return
	
	if current_player.traveling == 0 and current_player.traveling_destination == null:
		print("No active travel detected")
		# No active travel - show location expedition info
		var location_data = GameInfo.settlements_db.get_location_by_id(current_player.location)
		if location_data:
			quest_name_label.text = "Expedition"
			background.texture = location_data.expedition_texture
			travel_text_label.text = location_data.expedition_text if location_data.expedition_text != "" else "No active travel"
		else:
			travel_text_label.text = "No active travel"
		
		travel_progress.visible = false
		is_skipping = false
		skip_button.visible = false
		enter_dungeon_button.visible = true
		enter_dungeon_button.text = "Enter Dungeon"

		return
	
	# Currently traveling - show skip button, hide enter dungeon button
	travel_progress.visible = true
	skip_button.visible = true
	skip_button.disabled = false
	skip_button.text = "Skip"
	enter_dungeon_button.visible = false
	travel_text_label.text = travel_text

func _process(_delta):
	"""Update progress bar every frame for smooth 60fps animation"""
	print("QuestPanel._process called for travel update")
	var current_player = GameInfo.current_player
	
	# Only update if actively traveling
	if current_player.traveling == 0:
		return
	
	var current_time = Time.get_unix_time_from_system()
	var travel_end_time = current_player.traveling
	
	# Handle skipping animation - accelerate the countdown
	if is_skipping:
		var skip_elapsed = current_time - skip_start_time
		var skip_duration = 2.0  # 2 seconds to complete
		
		# Calculate accelerating progress (quadratic acceleration)
		var skip_progress = skip_elapsed / skip_duration
		skip_progress = skip_progress * skip_progress  # Square for acceleration effect
		
		if skip_progress >= 1.0:
			skip_progress = 1.0
		
		# Show accelerated time remaining
		var simulated_remaining = (original_travel_end - current_time) * (1.0 - skip_progress)
		travel_end_time = current_time + simulated_remaining
	
	var time_remaining = travel_end_time - current_time
	
	# Check if travel is completed (naturally or via skip)
	if time_remaining <= 0:
		set_process(false)  # Stop frame updates
		print("Travel completed - loading quest")
		
		# Reset state
		current_player.traveling = 0
		is_skipping = false
		refresh_travel_state()
		
		# Only auto-load quest if map panel is visible
		if visible:
			_on_enter_dungeon_pressed()
		return
	
	# Update skip button text
	if is_skipping:
		skip_button.text = "Skipping..."
	
	# Calculate progress using stored duration
	if travel_duration > 0:
		var elapsed_time = travel_duration - time_remaining
		travel_progress.value = (elapsed_time / travel_duration) * travel_progress.max_value
	
	# Format remaining time as MM:SS
	var minutes = int(time_remaining / 60)
	var seconds = int(time_remaining) % 60
	travel_time_label.text = "%02d:%02d" % [minutes, seconds]

func _on_skip_button_pressed():
	var current_player = GameInfo.current_player
	
	if current_player.traveling > 0 and not is_skipping:
		# Start skipping animation - will load quest after 2 seconds
		is_skipping = true
		skip_start_time = Time.get_unix_time_from_system()
		original_travel_end = current_player.traveling
		print("Travel skip started - accelerating countdown...")
		
		# Disable the skip button during animation
		skip_button.disabled = true

func _on_enter_dungeon_pressed():
	# Check if this is a quest (not dungeon)
	if GameInfo.current_player.traveling_destination != null:
		# Go Quest functionality
		print("Go Quest button pressed - loading quest")
		var quest_id = GameInfo.current_player.traveling_destination
		
		# Load quest directly
		UIManager.instance.quest.load_quest(quest_id)
		
	else:
		# Dungeon functionality (future)
		print("Enter dungeon button pressed - functionality not implemented yet")
