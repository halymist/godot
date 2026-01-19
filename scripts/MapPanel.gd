extends Panel

const SKIP_COST: int = 1  # Mushroom cost to skip travel

@export var quest_name_label: Label
@export var travel_text_label: Label
@export var travel_progress: TextureProgressBar
@export var travel_time_label: Label
@export var skip_button: Button
@export var enter_dungeon_button: Button
@export var background: TextureRect

var is_skipping: bool = false
var skip_start_time: float = 0.0
var skip_duration_target: float = 0.0  # Dynamic skip duration (remaining_time / 8)
var original_travel_end: float = 0.0

# Travel info set when quest is accepted
var travel_text: String
var travel_duration: float

# Expedition state
var is_expedition_travel: bool = false  # True when traveling to expedition (not quest)
var pending_expedition_slide_id: int = 0  # Slide ID received from server
var expedition_travel_end: float = 0.0  # When expedition travel ends

func _ready():
	# Always connect buttons and signals
	skip_button.pressed.connect(_on_skip_button_pressed)
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_pressed)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)  # Only process when traveling
	
	# Check if we're the starter panel
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)
    
	if UIManager.instance.starter_panel == self:
		UIManager.instance.game_is_ready = true
		UIManager.instance.game_ready.emit()

func _setup():
	# Initialize if character is already selected
	refresh_travel_state()
	print("MapPanel: Setup complete")

func _on_visibility_changed():
	# Refresh state when panel becomes visible
	if visible:
		refresh_travel_state()



func start_travel(quest_travel_text: String, duration_seconds: int, quest_id: int = 0):
	"""Start traveling with the given text and duration (0 for VIP = instant)"""
	travel_text = quest_travel_text
	# Override duration to always be 15 seconds (unless VIP with 0)
	if duration_seconds > 0:
		duration_seconds = 15
	travel_duration = float(duration_seconds)
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
	
	# Check if expedition travel is active (local timer, not stored in GameInfo)
	if is_expedition_travel and expedition_travel_end > Time.get_unix_time_from_system():
		# Currently traveling to expedition - show skip button, hide enter dungeon button
		travel_progress.visible = true
		skip_button.visible = true
		skip_button.disabled = is_skipping or not _can_afford_skip()
		skip_button.text = "Skipping..." if is_skipping else "Skip (1 🍄)"
		enter_dungeon_button.visible = false
		return
	
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
	skip_button.text = "Skip (1 🍄)"
	enter_dungeon_button.visible = false
	travel_text_label.text = travel_text

func _process(_delta):
	"""Update progress bar every frame for smooth 60fps animation"""
	var current_player = GameInfo.current_player
	var current_time = Time.get_unix_time_from_system()
	var travel_end_time: float = 0.0
	var is_traveling: bool = false
	
	# Check if we're traveling to expedition or quest
	if is_expedition_travel and expedition_travel_end > 0:
		travel_end_time = expedition_travel_end
		is_traveling = true
	elif current_player.traveling > 0:
		travel_end_time = current_player.traveling
		is_traveling = true
	
	# Only update if actively traveling
	if not is_traveling:
		return
	
	# Update skip button state based on mushroom availability
	if not is_skipping and skip_button.visible:
		skip_button.disabled = not _can_afford_skip()
	
	# Handle skipping animation - accelerate the countdown
	if is_skipping:
		var skip_elapsed = current_time - skip_start_time
		var skip_duration = skip_duration_target  # Dynamic duration based on remaining time
		
		# Calculate accelerating progress (quadratic acceleration)
		var skip_progress = skip_elapsed / skip_duration
		skip_progress = skip_progress * skip_progress  # Square for acceleration effect
		
		if skip_progress >= 1.0:
			skip_progress = 1.0
		
		# Show accelerated time remaining
		var simulated_remaining = (original_travel_end - current_time) * (1.0 - skip_progress)
		travel_end_time = current_time + simulated_remaining
	
	var time_remaining = travel_end_time - current_time
	
	# Hide skip button when 3 seconds or less remain (if not already skipping)
	if not is_skipping and time_remaining <= 3.0:
		skip_button.visible = false
	
	# Check if travel is completed (naturally or via skip)
	if time_remaining <= 0:
		set_process(false)  # Stop frame updates
		
		if is_expedition_travel:
			print("Expedition travel completed")
			expedition_travel_end = 0.0
			is_skipping = false
			is_expedition_travel = false
			
			# Update player's expedition state so is_on_expedition() returns true
			if pending_expedition_slide_id > 0:
				GameInfo.current_player.expedition = [pending_expedition_slide_id]
			
			refresh_travel_state()
			
			# Only auto-load expedition if map panel is visible
			if visible:
				_load_expedition()
		else:
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

func _can_afford_skip() -> bool:
	"""Check if player has enough mushrooms to skip"""
	return GameInfo.lobby_data.has("mushrooms") and GameInfo.lobby_data.mushrooms >= SKIP_COST

func _on_skip_button_pressed():
	var current_player = GameInfo.current_player
	
	# Check if we're traveling to expedition or quest
	var is_traveling = is_expedition_travel or current_player.traveling > 0
	
	if is_traveling and not is_skipping:
		# Check if player has enough mushrooms
		if not _can_afford_skip():
			print("Not enough mushrooms to skip travel")
			return
		
		# Deduct mushroom cost
		UIManager.instance.update_mushrooms(-SKIP_COST)
		print("Deducted ", SKIP_COST, " mushroom for skip")
		
		# Calculate remaining time
		var current_time = Time.get_unix_time_from_system()
		var travel_end_time: float
		if is_expedition_travel:
			travel_end_time = expedition_travel_end
		else:
			travel_end_time = current_player.traveling
		
		var remaining_time = travel_end_time - current_time
		
		# Calculate skip duration as remaining time / 8
		skip_duration_target = remaining_time / 8.0
		
		# Start skipping animation
		Websocket.skip_travel()
		is_skipping = true
		skip_start_time = current_time
		
		# Store the original end time based on travel type
		if is_expedition_travel:
			original_travel_end = expedition_travel_end
		else:
			original_travel_end = current_player.traveling
		
		print("Travel skip started - skip duration: ", skip_duration_target, " seconds")
		
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
		# Start expedition - send to server and begin timer
		print("Enter dungeon button pressed - starting expedition")
		start_expedition_travel()

func start_expedition_travel():
	"""Start traveling to an expedition (dungeon)"""
	# Check if player is VIP and has autoskip enabled
	var is_vip = GameInfo.current_player.vip if "vip" in GameInfo.current_player else false
	var autoskip = false
	if is_vip:
		autoskip = SettingsManager.get_setting("gameplay", "autoskip_quest")
	
	# Send start_expedition to server (no parameter - server knows everything)
	Websocket.start_expedition()
	
	# MOCK: Simulate server response with slide ID = 2
	# In production, this would come from server via receive_expedition_slide()
	pending_expedition_slide_id = 2
	print("MOCK: Server responded with expedition slide ID: ", pending_expedition_slide_id)
	
	# Autoskip OR VIP: Go directly to expedition panel
	# (User already on map, already read the text, no need for timer screen)
	if autoskip or is_vip:
		print("VIP or autoskip - going directly to expedition")
		# Update player's expedition state
		GameInfo.current_player.expedition = [pending_expedition_slide_id]
		# Load expedition panel
		_load_expedition()
		return
	
	# Non-VIP: Set up 15 second timer
	var travel_time = 15.0
	var current_time = Time.get_unix_time_from_system()
	expedition_travel_end = current_time + travel_time
	
	# Mark as expedition travel
	is_expedition_travel = true
	travel_duration = travel_time
	
	# Update UI
	var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location)
	if location_data:
		travel_text = location_data.expedition_text if location_data.expedition_text != "" else "Entering the dungeon..."
	else:
		travel_text = "Entering the dungeon..."
	
	travel_text_label.text = travel_text
	travel_progress.visible = true
	travel_progress.value = 0
	skip_button.visible = true
	skip_button.disabled = not _can_afford_skip()
	skip_button.text = "Skip (1 🍄)"
	enter_dungeon_button.visible = false
	
	set_process(true)  # Enable frame updates
	print("Expedition travel started - Duration: ", travel_time, " seconds")

func receive_expedition_slide(slide_id: int):
	"""Called when server responds with expedition slide ID"""
	print("Received expedition slide ID from server: ", slide_id)
	pending_expedition_slide_id = slide_id

func _load_expedition():
	"""Load the expedition panel with the pending slide ID"""
	if pending_expedition_slide_id <= 0:
		print("Error: No expedition slide ID received from server")
		return
	
	print("Loading expedition with slide ID: ", pending_expedition_slide_id)
	
	# Show expedition panel - use expedition ID 1 for now (server could send this too)
	UIManager.instance.expedition_panel.start_expedition(1, pending_expedition_slide_id)
	UIManager.instance.show_panel(UIManager.instance.expedition_panel)
	
	# Clear pending slide ID
	pending_expedition_slide_id = 0
