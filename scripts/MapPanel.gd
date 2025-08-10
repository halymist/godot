extends Panel
class_name MapPanel

@export var travel_text_label: Label
@export var travel_progress: ProgressBar
@export var travel_time_label: Label
@export var skip_button: Button
@export var enter_dungeon_button: Button
@export var quest: Control 
@export var ambadon: Control # Reference to the Ambadon quest panel

var update_timer: Timer
var is_skipping: bool = false
var skip_start_time: float = 0.0
var original_travel_end: float = 0.0

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
	
	# Initial update
	update_travel_display()

func update_travel_display():
	var current_player = GameInfo.current_player
	
	if current_player.traveling == null:
		# No active travel
		travel_text_label.text = "No active travel"
		travel_progress.value = 0
		travel_time_label.text = "00:00"
		is_skipping = false
		if skip_button:
			skip_button.visible = false
		if enter_dungeon_button:
			enter_dungeon_button.visible = true
		return
	
	var current_time = Time.get_unix_time_from_system()
	var travel_end_time = current_player.traveling
	
	# Handle skipping animation
	if is_skipping:
		var skip_elapsed = current_time - skip_start_time
		var skip_duration = 2.0  # 2 seconds to complete
		
		# Calculate accelerating progress (quadratic acceleration)
		var skip_progress = skip_elapsed / skip_duration
		skip_progress = skip_progress * skip_progress  # Square for acceleration effect
		
		if skip_progress >= 1.0:
			# Skip completed
			is_skipping = false
			current_player.traveling = null
			current_player.traveling_destination = null
			_on_travel_completed()
			return
		
		# Show accelerated time remaining
		var simulated_remaining = (original_travel_end - current_time) * (1.0 - skip_progress)
		travel_end_time = current_time + simulated_remaining
	
	var time_remaining = travel_end_time - current_time
	
	if time_remaining <= 0 and not is_skipping:
		# Travel completed naturally
		travel_text_label.text = "Travel completed!"
		travel_progress.value = 100
		travel_time_label.text = "00:00"
		if skip_button:
			skip_button.visible = false
		if enter_dungeon_button:
			enter_dungeon_button.visible = true
		
		# Clear travel data
		current_player.traveling = null
		current_player.traveling_destination = null
		return
	
	# Currently traveling - show skip button, hide enter dungeon button
	if skip_button:
		skip_button.visible = true
		skip_button.text = "Skip" if not is_skipping else "Skipping..."
	if enter_dungeon_button:
		enter_dungeon_button.visible = false
	
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
	var current_player = GameInfo.current_player
	
	if current_player.traveling != null and not is_skipping:
		# Start skipping animation
		is_skipping = true
		skip_start_time = Time.get_unix_time_from_system()
		original_travel_end = current_player.traveling
		print("Travel skip started - accelerating countdown...")
		
		# Disable the skip button during animation
		if skip_button:
			skip_button.disabled = true

func _on_travel_completed():
	print("Travel completed via skip - switching to Quest panel with transition")
	
	# Re-enable skip button
	if skip_button:
		skip_button.disabled = false
	
	# Add a smooth transition to quest panel
	var transition_tween = create_tween()
	transition_tween.set_ease(Tween.EASE_OUT)
	transition_tween.set_trans(Tween.TRANS_CUBIC)
	
	# First fade out current panel
	modulate = Color(1, 1, 1, 1)
	transition_tween.tween_property(self, "modulate", Color(1, 1, 1, 0.3), 0.2)
	
	# Then switch panels and fade back in
	transition_tween.tween_callback(_switch_to_quest_panel)
	transition_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

func _switch_to_quest_panel():
	# Find the TogglePanel and switch to Quest
	var toggle_panel = get_tree().current_scene.find_child("Portrait", true, false)
	if toggle_panel and toggle_panel.has_method("show_panel"):
		# Find the quest panel 
		var quest_panel = toggle_panel.get("quest_panel")
		if quest_panel:
			toggle_panel.show_panel(quest_panel)
			print("Switched to Quest panel")
		else:
			print("Quest panel not found")
	else:
		print("TogglePanel not found or missing show_panel method")

func _on_enter_dungeon_pressed():
	# Placeholder for dungeon functionality
	print("Enter dungeon button pressed - functionality not implemented yet")
