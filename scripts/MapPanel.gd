extends Panel
class_name MapPanel

@export var travel_text_label: Label
@export var travel_progress: ProgressBar
@export var travel_time_label: Label
@export var skip_button: Button

var update_timer: Timer

func _ready():
	# Get references to UI elements
	travel_text_label = $VBoxContainer/TravelTextPanel/TravelTextLabel
	travel_progress = $VBoxContainer/TravelBarContainer/TravelProgress
	travel_time_label = $VBoxContainer/TravelBarContainer/TravelTimeLabel
	skip_button = $VBoxContainer/SkipButton
	
	# Connect skip button
	if skip_button:
		skip_button.pressed.connect(_on_skip_button_pressed)
	
	# Create and setup timer for updating travel progress
	update_timer = Timer.new()
	update_timer.wait_time = 1.0  # Update every second
	update_timer.timeout.connect(update_travel_display)
	add_child(update_timer)
	update_timer.start()
	
	# Initial update
	update_travel_display()

func update_travel_display():
	var current_player = GameInfo.current_player
	
	if current_player.traveling == null:
		# No active travel
		travel_text_label.text = "No active travel"
		travel_progress.value = 0
		travel_time_label.text = "00:00"
		return
	
	var current_time = Time.get_unix_time_from_system()
	var travel_end_time = current_player.traveling
	var time_remaining = travel_end_time - current_time
	
	if time_remaining <= 0:
		# Travel completed
		travel_text_label.text = "Travel completed!"
		travel_progress.value = 100
		travel_time_label.text = "00:00"
		
		# Clear travel data
		current_player.traveling = null
		current_player.traveling_destination = null
		return
	
	# Get quest data for travel text
	var quest_id = current_player.traveling_destination
	var quest_data = _find_quest_by_id(quest_id)
	
	if quest_data:
		travel_text_label.text = quest_data.get("traveltext", "Traveling...")
	else:
		travel_text_label.text = "Traveling..."
	
	# Calculate progress (assuming we know the original travel duration)
	var original_duration = _get_original_travel_duration(quest_data)
	if original_duration > 0:
		var elapsed_time = original_duration - time_remaining
		var progress_percent = (elapsed_time / original_duration) * 100
		travel_progress.value = max(0, min(100, progress_percent))
	
	# Format remaining time as MM:SS
	var minutes = int(time_remaining / 60)
	var seconds = int(time_remaining) % 60
	travel_time_label.text = "%02d:%02d" % [minutes, seconds]

func _find_quest_by_id(quest_id) -> Dictionary:
	var websocket = get_node("/root/Websocket")
	if websocket and websocket.has_method("get") and websocket.get("mock_npcs"):
		for npc_data in websocket.mock_npcs:
			if npc_data.get("questid") == quest_id:
				return npc_data
	return {}

func _get_original_travel_duration(quest_data: Dictionary) -> float:
	if quest_data.is_empty():
		return 300.0  # Default 5 minutes in seconds
	
	var travel_minutes = quest_data.get("travel", 5)
	return travel_minutes * 60.0  # Convert to seconds

func _on_skip_button_pressed():
	# Placeholder for skip functionality
	print("Skip travel button pressed - functionality not implemented yet")
