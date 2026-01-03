extends Panel
class_name MapPanel

@export var quest_name_label: Label
@export var travel_text_label: Label
@export var travel_progress: TextureProgressBar
@export var travel_time_label: Label
@export var skip_button: Button
@export var enter_dungeon_button: Button
@export var quest: Control 
@export var background: TextureRect

var update_timer: Timer
var is_skipping: bool = false
var skip_start_time: float = 0.0
var original_travel_end: float = 0.0

# Travel info set when quest is accepted
var travel_text: String = "Traveling..."
var travel_duration: float = 300.0  # Default 5 minutes

func _ready():
	
	# Connect skip button
	if skip_button:
		skip_button.pressed.connect(_on_skip_button_pressed)
	
	# Connect enter dungeon button
	if enter_dungeon_button:
		enter_dungeon_button.pressed.connect(_on_enter_dungeon_pressed)
	
	# Create and setup timer for updating travel progress
	update_timer = Timer.new()
	update_timer.wait_time = 0.016  # Update at ~60 FPS for smooth animation
	update_timer.timeout.connect(update_travel_display)
	add_child(update_timer)
	update_timer.start()
	
	# Check if travel is already complete (old timestamp) - if so, complete immediately
	var current_player = GameInfo.current_player
	if current_player and current_player.traveling_destination != null:
		var current_time = Time.get_unix_time_from_system()
		var travel_end_time = current_player.traveling
		if travel_end_time != null and travel_end_time > 0:
			var time_remaining = travel_end_time - current_time
			if time_remaining <= 0:
				print("MapPanel: Travel already complete on startup, completing immediately")
				call_deferred("_on_travel_completed")
				return
	
	# Initial update
	update_travel_display()

func start_travel(quest_travel_text: String, duration_seconds: int, quest_id: int = 0):
	"""Start traveling with the given text and duration"""
	travel_text = quest_travel_text
	travel_duration = float(duration_seconds)  # Duration is already in seconds
	print("Started travel: '", travel_text, "' for ", duration_seconds, " seconds")
	print("Travel duration in seconds: ", travel_duration)
	
	# Apply quest background texture and set quest name
	if quest_id > 0 and background:
		var quest_data = GameInfo.get_quest_data(quest_id)
		if quest_data:
			if quest_data.background_texture:
				background.texture = quest_data.background_texture
				print("Applied quest background texture")
			if quest_name_label:
				quest_name_label.text = quest_data.quest_name
	
	# Force immediate UI update to show travel info
	call_deferred("update_travel_display")
	print("Travel UI update triggered")

func update_travel_display():
	var current_player = GameInfo.current_player
	
	if current_player.traveling == 0:
		# No active travel - show location expedition info
		var location_data = GameInfo.settlements_db.get_location_by_id(current_player.location)
		if location_data:
			if quest_name_label:
				quest_name_label.text = "Expedition"
			if location_data.expedition_texture and background:
				background.texture = location_data.expedition_texture
			travel_text_label.text = location_data.expedition_text if location_data.expedition_text != "" else "No active travel"
		else:
			travel_text_label.text = "No active travel"
		
		travel_progress.value = 0
		travel_time_label.text = ""
		is_skipping = false
		if skip_button:
			skip_button.visible = false
		if enter_dungeon_button:
			enter_dungeon_button.visible = true
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
		# Travel completed
		travel_text_label.text = "Travel completed!"
		travel_progress.value = travel_progress.max_value
		travel_time_label.text = "00:00"
		if skip_button:
			skip_button.visible = false
		if enter_dungeon_button:
			enter_dungeon_button.visible = true
		
		# Clear travel data and show quest panel
		is_skipping = false
		current_player.traveling = 0
		_on_travel_completed()
		return
	
	# Currently traveling - show skip button, hide enter dungeon button
	if skip_button:
		skip_button.visible = true
		skip_button.text = "Skip" if not is_skipping else "Skipping..."
	if enter_dungeon_button:
		enter_dungeon_button.visible = false
	
	# Use stored travel text instead of looking it up
	travel_text_label.text = travel_text
	
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
		# Start skipping animation
		is_skipping = true
		skip_start_time = Time.get_unix_time_from_system()
		original_travel_end = current_player.traveling
		print("Travel skip started - accelerating countdown...")
		
		# Disable the skip button during animation
		if skip_button:
			skip_button.disabled = true

func _on_travel_completed():
	print("Travel completed - clearing travel state and showing quest")
	var quest_id = GameInfo.current_player.traveling_destination
	GameInfo.current_player.traveling = 0
	
	# Re-enable skip button
	skip_button.disabled = false
	
	# Find the current slide from quest log
	var start_slide = 1
	for quest_log_entry in GameInfo.current_player.quest_log:
		if quest_log_entry.quest_id == quest_id:
			if quest_log_entry.slides.size() > 0:
				start_slide = quest_log_entry.slides[-1]
			break
	
	# Load quest directly on the quest panel, then show it
	if quest:
		quest.load_quest(quest_id, start_slide)
	
	# Call handle_quest_arrived on active toggle panel through UIManager to show quest panel
	if UIManager.instance.portrait_ui.visible:
		UIManager.instance.portrait_ui.handle_quest_arrived()
	elif UIManager.instance.wide_ui.visible:
		UIManager.instance.wide_ui.handle_quest_arrived()

func _on_enter_dungeon_pressed():
	# Placeholder for dungeon functionality
	print("Enter dungeon button pressed - functionality not implemented yet")
