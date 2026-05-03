extends TextureRect

const SKIP_COST: int = 1  # Mushroom cost to skip travel
const DEFAULT_TRAVEL_DURATION: float = 10.0

@export var quest_name_label: Label
@export var travel_text_label: Label
@export var travel_progress: TextureProgressBar
@export var travel_time_label: Label
@export var skip_button: Button
@export var enter_dungeon_button: Button

# Labels inside the buttons (for dynamic text updates)
@onready var skip_action_label: Label = skip_button.get_node_or_null("Content/ActionLabel")
@onready var enter_action_label: Label = enter_dungeon_button.get_node_or_null("Content/ActionLabel")

# Colors for button states
const COLOR_NORMAL = Color(0.85, 0.8, 0.7, 1.0)
const COLOR_DISABLED = Color(0.5, 0.5, 0.5, 1.0)

var is_skipping: bool = false
var skip_start_time: float = 0.0
var skip_duration_target: float = 0.0  # Dynamic skip duration (remaining_time / 8)
var original_travel_end: float = 0.0

# Travel info set when quest is accepted
var travel_text: String
var travel_duration: float

# Expedition state
var is_expedition_travel: bool = false  # True when traveling to expedition (not quest)
var pending_expedition_id: int = 0  # Expedition ID received from server
var pending_expedition_node_id: int = 0  # Node ID for expedition quest travel context
var pending_expedition_quest_id: int = 0  # Quest ID tied to pending expedition node
var expedition_travel_end: float = 0.0  # When expedition travel ends

# Arrival state - true when travel completed and waiting for user to click "Arrived"
var has_arrived: bool = false

func _ready():
	# Always connect buttons and signals
	skip_button.pressed.connect(_on_skip_button_pressed)
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_pressed)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)  # Only process when traveling
	
	# Wait for game_ready before setup
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	# Initialize if character is already selected
	_sync_travel_state_from_player()
	refresh_travel_state()
	print("MapPanel: Setup complete")

func _on_visibility_changed():
	# Refresh state when panel becomes visible
	if visible:
		_sync_travel_state_from_player()
		refresh_travel_state()

func _sync_travel_state_from_player():
	"""Derive travel flags/state from player data so map can initialize anytime."""
	if not GameInfo.current_player:
		return

	var now = Time.get_unix_time_from_system()
	var arrival_ts = float(GameInfo.current_player.traveling) if GameInfo.current_player.traveling != null else 0.0
	var destination = GameInfo.current_player.traveling_destination
	var expedition = GameInfo.current_player.expedition

	# Traveling active (arrival in future)
	if arrival_ts > now:
		has_arrived = false
		if destination != null:
			is_expedition_travel = false
		else:
			is_expedition_travel = true
			expedition_travel_end = arrival_ts
			if expedition and expedition.size() > 0 and pending_expedition_id <= 0:
				pending_expedition_id = expedition[0]
		_ensure_travel_ui_from_player()
		if travel_duration <= 0.0:
			travel_duration = DEFAULT_TRAVEL_DURATION
		_update_travel_progress(arrival_ts)
		set_process(true)
		return

	# Arrival reached (or VIP instant)
	set_process(false)
	if destination != null:
		is_expedition_travel = false
		has_arrived = true
		return
	if expedition and expedition.size() > 0:
		is_expedition_travel = true
		has_arrived = true
		if pending_expedition_id <= 0:
			pending_expedition_id = expedition[0]
		return

	# Idle
	is_expedition_travel = false
	has_arrived = false

func _update_travel_progress(travel_end_time: float):
	"""Update progress bar and time label based on a travel end timestamp."""
	var now = Time.get_unix_time_from_system()
	var total = travel_duration if travel_duration > 0.0 else DEFAULT_TRAVEL_DURATION
	total = max(1.0, total)
	var start_time = travel_end_time - total
	var elapsed_time = clamp(now - start_time, 0.0, total)
	if travel_progress:
		travel_progress.value = (elapsed_time / total) * travel_progress.max_value
	var remaining = max(0.0, travel_end_time - now)
	if travel_time_label:
		var minutes = int(remaining / 60)
		var seconds = int(remaining) % 60
		travel_time_label.text = "%02d:%02d" % [minutes, seconds]

func _ensure_travel_ui_from_player():
	"""Hydrate travel UI fields when opening the map or on startup."""
	if not GameInfo.current_player:
		return

	# If a quest destination exists, hydrate from quest data
	if GameInfo.current_player.traveling_destination != null:
		var quest_id = int(GameInfo.current_player.traveling_destination)
		var quest_data = GameInfo.quests_db.get_quest_by_id(quest_id) if GameInfo.quests_db else null
		var is_expedition_node_quest = pending_expedition_node_id > 0 and pending_expedition_quest_id == quest_id

		# Expedition-node quests should keep the expedition settlement image while traveling.
		if is_expedition_node_quest:
			var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location) if GameInfo.settlements_db else null
			if location_data and location_data.expedition_texture:
				texture = location_data.expedition_texture
		elif quest_data and quest_data.background_texture:
			texture = quest_data.background_texture

		if quest_data:
			if quest_name_label:
				quest_name_label.text = quest_data.quest_name
			travel_text = quest_data.travel_text if quest_data.travel_text else "Traveling..."
		else:
			if quest_name_label:
				quest_name_label.text = "Quest %d" % quest_id
			travel_text = "Traveling..."

		if travel_text_label:
			travel_text_label.text = travel_text
		return

	# Otherwise hydrate expedition idle state
	if quest_name_label:
		quest_name_label.text = "Travel"
	travel_text = "No active travel"
	if travel_text_label:
		travel_text_label.text = travel_text



func start_travel(quest_travel_text: String, duration_seconds: int, quest_id: int = 0):
	"""Start traveling with the given text and duration (0 for VIP = instant)"""
	travel_text = quest_travel_text
	# Override duration to always be 10 seconds (unless VIP with 0)
	if duration_seconds > 0:
		duration_seconds = 10
	travel_duration = float(duration_seconds)
	print("Started travel: '", travel_text, "' for ", duration_seconds, " seconds (VIP=instant)" if duration_seconds == 0 else " seconds")
	print("Travel duration in seconds: ", travel_duration)
	set_process(true)  # Enable frame-by-frame updates for smooth progress
	
	# Set player travel state so refresh_travel_state() enters the correct branch
	if quest_id > 0 and GameInfo.current_player:
		GameInfo.current_player.traveling_destination = quest_id
		if duration_seconds > 0:
			GameInfo.current_player.traveling = Time.get_unix_time_from_system() + duration_seconds
		else:
			# VIP instant: traveling in the past means "already arrived"
			GameInfo.current_player.traveling = 0.0
		# Notify server
		Websocket.accept_quest(quest_id)
	
	# Apply quest background texture and set quest name
	var quest_data = GameInfo.quests_db.get_quest_by_id(quest_id) if GameInfo.quests_db else null
	if quest_data:
		if quest_data.background_texture:
			texture = quest_data.background_texture
			print("Applied quest background texture")
		if quest_name_label:
			quest_name_label.text = quest_data.quest_name
	
	refresh_travel_state()
	print("Travel UI update triggered")

func refresh_travel_state():
	"""Update UI state based on current travel status - call this when state changes"""
	var current_player = GameInfo.current_player
	var now = Time.get_unix_time_from_system()

	# Ensure we have travel UI text/background when opening the panel later
	_ensure_travel_ui_from_player()
	
	# ── State 1: Currently traveling (expedition or quest timer running) ──
	if is_expedition_travel and expedition_travel_end > now:
		# Expedition travel in progress
		if travel_duration <= 0.0 and expedition_travel_end > 0.0:
			travel_duration = max(1.0, expedition_travel_end - now)
		travel_progress.visible = true
		skip_button.visible = true
		var skip_disabled = is_skipping or not _can_afford_skip()
		skip_button.disabled = skip_disabled
		_update_button_label_colors(skip_button, skip_disabled)
		if skip_action_label:
			skip_action_label.text = "Skipping..." if is_skipping else "Skip ("
		enter_dungeon_button.visible = false
		_update_travel_progress(expedition_travel_end)
		return
	
	if current_player.traveling > now:
		# Quest travel in progress
		if travel_duration <= 0.0:
			travel_duration = max(1.0, current_player.traveling - now)
		travel_progress.visible = true
		skip_button.visible = true
		skip_button.disabled = false
		_update_button_label_colors(skip_button, false)
		if skip_action_label:
			skip_action_label.text = "Skip ("
		enter_dungeon_button.visible = false
		if travel_text_label:
			travel_text_label.text = travel_text
		_update_travel_progress(current_player.traveling)
		return
	
	# ── State 2: Arrived (travel finished, waiting for user to click) ──
	if has_arrived:
		travel_progress.visible = false
		if travel_time_label:
			travel_time_label.text = ""
		skip_button.visible = false
		enter_dungeon_button.visible = true
		enter_dungeon_button.disabled = false
		_update_button_label_colors(enter_dungeon_button, false)
		if enter_action_label:
			enter_action_label.text = "Arrived"
		# Hide the price section for Arrived
		_set_enter_price_visible(false)
		return
	
	# ── State 3: VIP instant arrival (destination set, no timer) ──
	if current_player.traveling_destination != null and current_player.traveling <= now:
		# VIP instant - show Arrived immediately
		if travel_text_label:
			travel_text_label.text = travel_text
		travel_progress.value = travel_progress.max_value
		if travel_time_label:
			travel_time_label.text = ""
		skip_button.visible = false
		enter_dungeon_button.visible = true
		enter_dungeon_button.disabled = false
		_update_button_label_colors(enter_dungeon_button, false)
		if enter_action_label:
			enter_action_label.text = "Arrived"
		# Hide the price section
		_set_enter_price_visible(false)
		return
	
	# ── State 4: Idle (map should not be used as expedition entry anymore) ──
	print("MapPanel idle state - no active travel")
	travel_progress.visible = false
	if travel_time_label:
		travel_time_label.text = ""
	is_skipping = false
	skip_button.visible = false
	enter_dungeon_button.visible = false
	_set_enter_price_visible(false)
	if quest_name_label:
		quest_name_label.text = "Travel"
	if travel_text_label:
		travel_text_label.text = "No active travel"

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
	elif current_player.traveling > current_time:
		travel_end_time = current_player.traveling
		is_traveling = true
	elif current_player.traveling > 0 and current_player.traveling <= current_time and current_player.traveling_destination != null:
		# Timer just expired this frame — mark as arrived
		has_arrived = true
		current_player.traveling = 0
		set_process(false)
		print("Quest travel completed - showing Arrived button")
		refresh_travel_state()
		return
	
	# Only update if actively traveling
	if not is_traveling:
		return
	
	# Update skip button state based on mushroom availability
	if not is_skipping and skip_button.visible:
		var skip_disabled = not _can_afford_skip()
		if skip_button.disabled != skip_disabled:
			skip_button.disabled = skip_disabled
			_update_button_label_colors(skip_button, skip_disabled)
	
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
		is_skipping = false
		has_arrived = true
		
		if is_expedition_travel:
			print("Expedition travel completed - showing Arrived button")
			expedition_travel_end = 0.0
		else:
			print("Quest travel completed - showing Arrived button")
			current_player.traveling = 0
		
		refresh_travel_state()
		return
	
	# Update skip button text
	if is_skipping and skip_action_label:
		skip_action_label.text = "Skipping..."
	
	# Calculate progress using stored duration
	if travel_duration > 0:
		var elapsed_time = travel_duration - time_remaining
		travel_progress.value = (elapsed_time / travel_duration) * travel_progress.max_value
	
	# Format remaining time as MM:SS
	var minutes = int(time_remaining / 60)
	var seconds = int(time_remaining) % 60
	if travel_time_label:
		if travel_time_label:
			travel_time_label.text = "%02d:%02d" % [minutes, seconds]

func _can_afford_skip() -> bool:
	"""Check if player has enough mushrooms to skip"""
	return GameInfo.lobby_data.has("mushrooms") and GameInfo.lobby_data.mushrooms >= SKIP_COST

func _update_button_label_colors(button: Button, disabled: bool):
	"""Update all label colors in a button based on disabled state"""
	var color = COLOR_DISABLED if disabled else COLOR_NORMAL
	var content = button.get_node_or_null("Content")
	if content:
		for child in content.get_children():
			if child is Label:
				child.add_theme_color_override("font_color", color)

func _set_enter_price_visible(price_visible: bool):
	var price_label = enter_dungeon_button.get_node_or_null("Content/PriceLabel")
	var currency_icon = enter_dungeon_button.get_node_or_null("Content/CurrencyIcon")
	var closing_paren = enter_dungeon_button.get_node_or_null("Content/ClosingParen")
	if price_label:
		price_label.visible = price_visible
	if currency_icon:
		currency_icon.visible = price_visible
	if closing_paren:
		closing_paren.visible = price_visible

func _on_skip_button_pressed():
	var current_player = GameInfo.current_player
	
	# Check if we're traveling to expedition or quest
	var is_traveling = is_expedition_travel or current_player.traveling > Time.get_unix_time_from_system()
	
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
	# ── Arrived state: load the quest or expedition ──
	if has_arrived:
		has_arrived = false
		
		if is_expedition_travel:
			# Expedition arrived - load expedition panel
			print("Arrived pressed - loading expedition")
			is_expedition_travel = false
			if pending_expedition_id > 0:
				GameInfo.current_player.expedition = [pending_expedition_id]
			_load_expedition()
		else:
			# Quest arrived - load quest panel
			print("Arrived pressed - loading quest")
			_load_arrived_quest()
		return
	
	# ── VIP instant arrival for quest ──
	if GameInfo.current_player.traveling_destination != null:
		print("Arrived pressed (VIP) - loading quest")
		_load_arrived_quest()
		return

	print("MapPanel enter ignored: no active travel or arrival state")

func _load_arrived_quest():
	if not GameInfo.current_player:
		return

	var quest_id = int(GameInfo.current_player.traveling_destination)
	if quest_id <= 0:
		print("MapPanel: No arrived quest to load")
		return

	# Preserve expedition-node return context when this quest came from expedition graph.
	if pending_expedition_node_id > 0 and pending_expedition_quest_id == quest_id and pending_expedition_id > 0:
		UIManager.instance.quest.load_expedition_node(pending_expedition_id, pending_expedition_node_id, quest_id)
		_clear_pending_expedition_node_context()
		return

	UIManager.instance.quest.load_quest(quest_id)

func load_arrived_quest():
	"""Public wrapper for loading the current arrived quest with proper context."""
	_load_arrived_quest()

func start_expedition_node_travel(expedition_id: int, node_id: int, quest_id: int, arrival_timestamp: String):
	"""Start quest travel for a selected expedition node using server-provided arrival."""
	if not GameInfo.current_player:
		return

	pending_expedition_id = expedition_id
	pending_expedition_node_id = node_id
	pending_expedition_quest_id = quest_id

	if expedition_id > 0:
		GameInfo.current_player.expedition = [expedition_id]
	GameInfo.current_player.traveling_destination = quest_id

	var now = Time.get_unix_time_from_system()
	var arrival_ts = _parse_iso8601_timestamp(arrival_timestamp)
	if arrival_ts > now:
		GameInfo.current_player.traveling = arrival_ts
		travel_duration = max(1.0, arrival_ts - now)
		has_arrived = false
		set_process(true)
	else:
		# If arrival is now/past, treat as instant arrival.
		GameInfo.current_player.traveling = 0.0
		travel_duration = DEFAULT_TRAVEL_DURATION
		has_arrived = true
		set_process(false)

	is_expedition_travel = false
	expedition_travel_end = 0.0
	_ensure_travel_ui_from_player()
	refresh_travel_state()

	print("MapPanel: Expedition node travel started node=", node_id, " quest=", quest_id, " arrival_ts=", GameInfo.current_player.traveling)
	if UIManager.instance:
		UIManager.instance.show_panel(self)

func receive_expedition_start(expedition_id: int, arrival_timestamp: String):
	"""Called when server responds with expedition start data"""
	print("Received expedition start - expedition_id: ", expedition_id, ", arrival: ", arrival_timestamp)
	
	pending_expedition_id = expedition_id
	is_expedition_travel = true
	
	# Check if player is VIP
	var is_vip = GameInfo.current_player.vip if "vip" in GameInfo.current_player else false
	
	# VIP: Show Arrived button immediately (no timer)
	if is_vip:
		print("VIP - showing Arrived button immediately")
		has_arrived = true
		expedition_travel_end = 0.0
		refresh_travel_state()
		return
	
	# Non-VIP: Use 10 second timer
	var current_time = Time.get_unix_time_from_system()
	var travel_time = 10.0  # Fixed 10 seconds for non-VIP
	
	expedition_travel_end = current_time + travel_time
	
	travel_duration = travel_time
	
	# Update UI
	var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location)
	if location_data:
		travel_text = location_data.expedition_text if location_data.expedition_text != "" else "Entering the dungeon..."
	else:
		travel_text = "Entering the dungeon..."
	
	if travel_text_label:
		travel_text_label.text = travel_text
	travel_progress.visible = true
	travel_progress.value = 0
	skip_button.visible = true
	skip_button.disabled = not _can_afford_skip()
	if skip_action_label:
		skip_action_label.text = "Skip ("
	enter_dungeon_button.visible = false
	
	set_process(true)  # Enable frame updates
	print("Expedition travel started - Duration: ", travel_time, " seconds (synced with server)")

func _parse_iso8601_timestamp(timestamp: String) -> float:
	"""Parse ISO8601 timestamp to Unix time"""
	if timestamp == null or timestamp == "":
		return Time.get_unix_time_from_system()

	# Format: "2026-01-29T17:48:16Z"
	# We'll use Time.get_datetime_dict_from_datetime_string() for Godot 4.x
	var parts = timestamp.split("T")
	if parts.size() != 2:
		print("Invalid timestamp format: ", timestamp)
		return Time.get_unix_time_from_system() + 10.0  # Fallback to 10 seconds
	
	var date_parts = parts[0].split("-")
	var time_str = parts[1].replace("Z", "")
	var time_parts = time_str.split(":")
	
	if date_parts.size() != 3 or time_parts.size() != 3:
		print("Invalid timestamp format: ", timestamp)
		return Time.get_unix_time_from_system() + 10.0
	
	var datetime = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": int(time_parts[0]),
		"minute": int(time_parts[1]),
		"second": int(time_parts[2])
	}
	
	return Time.get_unix_time_from_datetime_dict(datetime)

func _load_expedition():
	"""Load the expedition panel with the pending expedition ID"""
	if pending_expedition_id <= 0:
		print("Error: No expedition ID received from server")
		return
	
	print("Loading expedition with ID: ", pending_expedition_id)
	
	UIManager.instance.expedition_panel.start_expedition(pending_expedition_id)
	UIManager.instance.show_panel(UIManager.instance.expedition_panel)
	
	# Clear pending expedition ID
	pending_expedition_id = 0

func reset_expedition_state():
	"""Clear expedition travel flags and refresh UI"""
	is_expedition_travel = false
	pending_expedition_id = 0
	expedition_travel_end = 0.0
	has_arrived = false
	_clear_pending_expedition_node_context()
	refresh_travel_state()

func _clear_pending_expedition_node_context():
	pending_expedition_node_id = 0
	pending_expedition_quest_id = 0
