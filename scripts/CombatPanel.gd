extends Panel

# Combat panel that displays combat log data from GameInfo

@onready var player_icon = $CharacterArea/CharacterContainer/PlayerSection/PlayerIcon
@onready var player_health_bar = $CharacterArea/CharacterContainer/PlayerSection/PlayerHealthBar
@onready var player_label = $CharacterArea/CharacterContainer/PlayerSection/PlayerLabel
@onready var enemy_icon = $CharacterArea/CharacterContainer/EnemySection/EnemyIcon
@onready var enemy_health_bar = $CharacterArea/CharacterContainer/EnemySection/EnemyHealthBar
@onready var enemy_label = $CharacterArea/CharacterContainer/EnemySection/EnemyLabel
@onready var player_log_container = $CombatLogArea/PlayerLogSection/PlayerLogScroll/PlayerLogContainer
@onready var enemy_log_container = $CombatLogArea/EnemyLogSection/EnemyLogScroll/EnemyLogContainer
@onready var combat_result = $CombatResult
@onready var skip_replay_button = $SkipReplayButton

var current_turn = 0
var display_timer: Timer
var is_combat_finished = false
var current_player1_health: float
var current_player2_health: float
var reaction_timer: Timer
var pending_reaction_entry = null
var pending_reaction_container = null

# For log synchronization
var player_log_entries = []
var enemy_log_entries = []

func _ready():
	# Create timer for displaying combat log entries
	display_timer = Timer.new()
	display_timer.wait_time = 0.8  # Faster speed: 0.8 seconds instead of 1.5
	display_timer.timeout.connect(_display_next_entry)
	add_child(display_timer)
	
	# Create timer for delayed reactions
	reaction_timer = Timer.new()
	reaction_timer.wait_time = 0.4  # Short delay for reactions
	reaction_timer.timeout.connect(_display_pending_reaction)
	reaction_timer.one_shot = true
	add_child(reaction_timer)
	
	# Connect to visibility changes
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect button signal
	skip_replay_button.pressed.connect(_on_skip_replay_pressed)

func display_combat_log():
	if not GameInfo.current_combat_log:
		print("No current combat log to display")
		return
	
	var combat = GameInfo.current_combat_log
	
	# Set up character info
	player_label.text = combat.player1_name
	enemy_label.text = combat.player2_name
	
	# Set initial health bars and store starting values
	player_health_bar.max_value = combat.player1_health
	enemy_health_bar.max_value = combat.player2_health
	player_health_bar.value = combat.player1_health
	enemy_health_bar.value = combat.player2_health
	current_player1_health = combat.player1_health
	current_player2_health = combat.player2_health
	
	# Clear existing log entries
	clear_log_containers()
	
	# Prepare synchronized log entries
	prepare_synchronized_logs(combat)
	
	# Reset state
	current_turn = 0
	is_combat_finished = false
	combat_result.text = ""
	skip_replay_button.text = "Skip"
	
	if player_log_entries.size() > 0 or enemy_log_entries.size() > 0:
		display_timer.start()
	else:
		combat_result.text = combat.final_message
		is_combat_finished = true
		skip_replay_button.text = "Replay"

func clear_log_containers():
	for child in player_log_container.get_children():
		child.queue_free()
	for child in enemy_log_container.get_children():
		child.queue_free()

func prepare_synchronized_logs(combat: GameInfo.CombatResponse):
	player_log_entries.clear()
	enemy_log_entries.clear()
	
	# Group entries by turn and player
	var turns_data = {}
	for entry in combat.combat_log:
		if not turns_data.has(entry.turn):
			turns_data[entry.turn] = {"player1": [], "player2": []}
		
		if entry.player == combat.player1_name:
			turns_data[entry.turn]["player1"].append(entry)
		else:
			turns_data[entry.turn]["player2"].append(entry)
	
	# Find the maximum turn number
	var max_turn = 0
	for turn in turns_data.keys():
		max_turn = max(max_turn, turn)
	
	# Process each turn and ensure both sides have the same number of rows
	for turn in range(1, max_turn + 1):
		var player1_actions = []
		var player2_actions = []
		
		if turns_data.has(turn):
			player1_actions = turns_data[turn]["player1"]
			player2_actions = turns_data[turn]["player2"]
		
		# Find the maximum number of actions in this turn
		var max_actions = max(player1_actions.size(), player2_actions.size())
		
		# Add actions and fill with nulls to match the max
		for i in range(max_actions):
			# Add player1 action or null
			if i < player1_actions.size():
				player_log_entries.append(player1_actions[i])
			else:
				player_log_entries.append(null)
			
			# Add player2 action or null
			if i < player2_actions.size():
				enemy_log_entries.append(player2_actions[i])
			else:
				enemy_log_entries.append(null)

func _display_next_entry():
	if current_turn >= player_log_entries.size():
		display_timer.stop()
		combat_result.text = GameInfo.current_combat_log.final_message if GameInfo.current_combat_log else "Combat Complete"
		is_combat_finished = true
		skip_replay_button.text = "Replay"
		return
	
	# Get entries for current turn
	var player_entry = player_log_entries[current_turn]
	var enemy_entry = enemy_log_entries[current_turn]
	
	# Determine which is action and which is reaction
	var action_entry = null
	var reaction_entry = null
	var action_container = null
	var reaction_container = null
	
	if player_entry and player_entry.action in ["attack", "dodge"]:
		action_entry = player_entry
		reaction_entry = enemy_entry
		action_container = player_log_container
		reaction_container = enemy_log_container
	elif enemy_entry and enemy_entry.action in ["attack", "dodge"]:
		action_entry = enemy_entry
		reaction_entry = player_entry
		action_container = enemy_log_container
		reaction_container = player_log_container
	else:
		# Handle case where neither is a clear action (fallback)
		action_entry = player_entry
		reaction_entry = enemy_entry
		action_container = player_log_container
		reaction_container = enemy_log_container
	
	# Display action immediately
	var action_label = Label.new()
	if action_entry:
		action_label.text = format_combat_entry(action_entry)
	else:
		action_label.text = ""
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_label.add_theme_font_size_override("font_size", 14)
	action_container.add_child(action_label)
	
	# Store reaction for delayed display
	pending_reaction_entry = reaction_entry
	pending_reaction_container = reaction_container
	
	# Start reaction timer
	if reaction_entry:
		reaction_timer.start()
	else:
		# No reaction, add empty label immediately
		var empty_label = Label.new()
		empty_label.text = ""
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 14)
		reaction_container.add_child(empty_label)
	
	current_turn += 1

func _display_pending_reaction():
	if pending_reaction_entry and pending_reaction_container:
		var reaction_label = Label.new()
		reaction_label.text = format_combat_entry(pending_reaction_entry)
		reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reaction_label.add_theme_font_size_override("font_size", 14)
		pending_reaction_container.add_child(reaction_label)
		
		# Apply health changes for reactions
		if pending_reaction_entry.action.contains("hit"):
			var combat = GameInfo.current_combat_log
			if combat:
				if pending_reaction_entry.player == combat.player1_name:
					animate_health_decrease(player_health_bar, pending_reaction_entry.factor)
				else:
					animate_health_decrease(enemy_health_bar, pending_reaction_entry.factor)
	
	# Clear pending reaction
	pending_reaction_entry = null
	pending_reaction_container = null

func format_combat_entry(entry: GameInfo.CombatLogEntry) -> String:
	var text = "Turn " + str(entry.turn) + ": "
	
	match entry.action:
		"attack":
			text += entry.player + " attacks!"
		"dodge":
			text += entry.player + " dodges!"
		"hit":
			if entry.factor > 0:
				text += entry.player + " takes " + str(entry.factor) + " damage!"
			else:
				text += entry.player + " is hit!"
		"miss":
			text += entry.player + " misses!"
		_:
			text += entry.player + " " + entry.action
			if entry.factor > 0:
				text += " (" + str(entry.factor) + ")"
	
	return text

func animate_health_decrease(health_bar: ProgressBar, damage: int):
	if damage <= 0:
		return
	
	var new_health = max(0, health_bar.value - damage)
	
	# Create tween for smooth health bar animation
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)
	tween.tween_callback(func(): pass)  # Optional callback when animation completes

func update_health_from_entry(entry: GameInfo.CombatLogEntry):
	# This function is kept for compatibility but now we use animate_health_decrease
	var combat = GameInfo.current_combat_log
	if not combat:
		return
	
	if entry.player == combat.player1_name and entry.action.contains("hit"):
		animate_health_decrease(player_health_bar, entry.factor)
	elif entry.player == combat.player2_name and entry.action.contains("hit"):
		animate_health_decrease(enemy_health_bar, entry.factor)

# Called when the combat panel becomes visible
func _on_visibility_changed():
	if visible:
		display_combat_log()

# Button handler for skip/replay
func _on_skip_replay_pressed():
	if is_combat_finished:
		# Replay the combat
		display_combat_log()
	else:
		# Skip to the end
		display_timer.stop()
		# Show all remaining entries instantly
		while current_turn < player_log_entries.size():
			var player_entry = player_log_entries[current_turn]
			var enemy_entry = enemy_log_entries[current_turn]
			
			# Add player log entry (or empty space)
			var player_log_label = Label.new()
			if player_entry:
				player_log_label.text = format_combat_entry(player_entry)
				if player_entry.action.contains("hit"):
					player_health_bar.value = max(0, player_health_bar.value - player_entry.factor)
			else:
				player_log_label.text = ""
			
			player_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			player_log_label.add_theme_font_size_override("font_size", 14)
			player_log_container.add_child(player_log_label)
			
			# Add enemy log entry (or empty space)
			var enemy_log_label = Label.new()
			if enemy_entry:
				enemy_log_label.text = format_combat_entry(enemy_entry)
				if enemy_entry.action.contains("hit"):
					enemy_health_bar.value = max(0, enemy_health_bar.value - enemy_entry.factor)
			else:
				enemy_log_label.text = ""
			
			enemy_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			enemy_log_label.add_theme_font_size_override("font_size", 14)
			enemy_log_container.add_child(enemy_log_label)
			
			current_turn += 1
		
		if GameInfo.current_combat_log:
			combat_result.text = GameInfo.current_combat_log.final_message
		is_combat_finished = true
		skip_replay_button.text = "Replay"
