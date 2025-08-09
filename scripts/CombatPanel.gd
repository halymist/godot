extends Panel

# Combat panel that displays combat log data from GameInfo

@onready var player_icon = $CharacterArea/CharacterContainer/PlayerSection/PlayerIcon
@onready var player_health_bar = $CharacterArea/CharacterContainer/PlayerSection/PlayerHealthBar
@onready var player_label = $CharacterArea/CharacterContainer/PlayerSection/PlayerLabel
@onready var enemy_icon = $CharacterArea/CharacterContainer/EnemySection/EnemyIcon
@onready var enemy_health_bar = $CharacterArea/CharacterContainer/EnemySection/EnemyHealthBar
@onready var enemy_label = $CharacterArea/CharacterContainer/EnemySection/EnemyLabel
@onready var combat_log_container = $CombatLogArea/UnifiedLogScroll/CombatLogContainer
@onready var combat_result = $CombatResult
@onready var skip_replay_button = $SkipReplayButton
@onready var unified_scroll = $CombatLogArea/UnifiedLogScroll

var current_turn_display = 0
var display_timer: Timer
var action_timer: Timer
var is_combat_finished = false
var current_player1_health: float
var current_player2_health: float

# For turn-based display
var organized_turns = []
var current_action_index = 0
var all_actions = []
var is_displaying_actions = false

func _ready():
	# Create timer for displaying combat turns
	display_timer = Timer.new()
	display_timer.wait_time = 1.5  # 1.5 seconds per turn
	display_timer.timeout.connect(_display_next_turn)
	add_child(display_timer)
	
	# Create timer for individual actions
	action_timer = Timer.new()
	action_timer.wait_time = 0.6  # 0.6 seconds per action
	action_timer.timeout.connect(_display_next_action)
	add_child(action_timer)
	
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
	
	# Organize combat data by turns
	organize_combat_by_turns(combat)
	
	# Create a flat list of all actions for sequential display
	create_action_sequence()
	
	# Reset state
	current_turn_display = 0
	current_action_index = 0
	is_combat_finished = false
	is_displaying_actions = false
	combat_result.text = ""
	skip_replay_button.text = "Skip"
	
	if organized_turns.size() > 0:
		display_timer.start()
	else:
		combat_result.text = combat.final_message
		is_combat_finished = true
		skip_replay_button.text = "Replay"

func clear_log_containers():
	for child in combat_log_container.get_children():
		child.queue_free()

func organize_combat_by_turns(combat: GameInfo.CombatResponse):
	organized_turns.clear()
	
	# Group entries by turn
	var turns_data = {}
	for entry in combat.combat_log:
		if not turns_data.has(entry.turn):
			turns_data[entry.turn] = []
		turns_data[entry.turn].append(entry)
	
	# Sort turns and organize them
	var turn_numbers = turns_data.keys()
	turn_numbers.sort()
	
	for turn_num in turn_numbers:
		var turn_entries = turns_data[turn_num]
		var turn_data = {
			"turn_number": turn_num,
			"player1_actions": [],
			"player2_actions": []
		}
		
		# Separate actions by player
		for entry in turn_entries:
			if entry.player == combat.player1_name:
				turn_data.player1_actions.append(entry)
			else:
				turn_data.player2_actions.append(entry)
		
		organized_turns.append(turn_data)

func create_action_sequence():
	all_actions.clear()
	
	for turn_data in organized_turns:
		# Add turn header action
		all_actions.append({
			"type": "turn_header",
			"turn_number": turn_data.turn_number
		})
		
		# Create a flat list of all individual actions for this turn
		var all_turn_actions = []
		
		# Add all player1 actions
		for action in turn_data.player1_actions:
			all_turn_actions.append({
				"type": "individual_action",
				"action": action,
				"player_side": "player1"
			})
		
		# Add all player2 actions
		for action in turn_data.player2_actions:
			all_turn_actions.append({
				"type": "individual_action", 
				"action": action,
				"player_side": "player2"
			})
		
		# Sort actions by their original order in combat log to maintain sequence
		all_turn_actions.sort_custom(func(a, b): 
			return GameInfo.current_combat_log.combat_log.find(a.action) < GameInfo.current_combat_log.combat_log.find(b.action)
		)
		
		# Add each individual action to the sequence
		for action_data in all_turn_actions:
			all_actions.append(action_data)

func _display_next_turn():
	if not is_displaying_actions:
		# This is the first turn - start action sequence
		display_timer.stop()
		is_displaying_actions = true
		current_action_index = 0
		action_timer.start()

func _display_next_action():
	if current_action_index >= all_actions.size():
		action_timer.stop()
		combat_result.text = GameInfo.current_combat_log.final_message if GameInfo.current_combat_log else "Combat Complete"
		is_combat_finished = true
		skip_replay_button.text = "Replay"
		call_deferred("smooth_scroll_to_bottom")
		return
	
	var action_data = all_actions[current_action_index]
	
	if action_data.type == "turn_header":
		display_turn_header(action_data.turn_number)
	elif action_data.type == "individual_action":
		display_individual_action(action_data)
	
	current_action_index += 1
	call_deferred("smooth_scroll_to_bottom")

func display_turn_header(turn_number: int):
	# Create turn separator and title
	var turn_separator_top = HSeparator.new()
	turn_separator_top.add_theme_color_override("separator", Color(0.6, 0.4, 0.2, 0.8))
	combat_log_container.add_child(turn_separator_top)
	
	# Turn title
	var turn_title = Label.new()
	turn_title.text = "Turn " + str(turn_number)
	turn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_title.add_theme_font_size_override("font_size", 16)
	turn_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4, 1))
	turn_title.add_theme_color_override("font_shadow_color", Color.BLACK)
	turn_title.add_theme_constant_override("shadow_offset_x", 1)
	turn_title.add_theme_constant_override("shadow_offset_y", 1)
	combat_log_container.add_child(turn_title)
	
	# Bottom separator
	var turn_separator_bottom = HSeparator.new()
	turn_separator_bottom.add_theme_color_override("separator", Color(0.6, 0.4, 0.2, 0.8))
	combat_log_container.add_child(turn_separator_bottom)
	
	# Create actions container for this turn if it doesn't exist
	var actions_container = HBoxContainer.new()
	actions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_container.name = "ActionsContainer_" + str(turn_number)
	combat_log_container.add_child(actions_container)
	
	# Player actions column
	var player_column = VBoxContainer.new()
	player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_column.name = "PlayerColumn"
	actions_container.add_child(player_column)
	
	# Enemy actions column  
	var enemy_column = VBoxContainer.new()
	enemy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_column.name = "EnemyColumn"
	actions_container.add_child(enemy_column)

func display_individual_action(action_data: Dictionary):
	# Find the most recent actions container
	var actions_container = null
	for i in range(combat_log_container.get_child_count() - 1, -1, -1):
		var child = combat_log_container.get_child(i)
		if child is HBoxContainer and child.name.begins_with("ActionsContainer_"):
			actions_container = child
			break
	
	if not actions_container:
		return
	
	var action = action_data.action
	var player_side = action_data.player_side
	
	# Determine which column to add to
	var target_column = null
	if player_side == "player1":
		target_column = actions_container.get_node("PlayerColumn")
	else:
		target_column = actions_container.get_node("EnemyColumn")
	
	if target_column:
		# Create and add the action label
		var action_label = Label.new()
		action_label.text = format_combat_entry(action)
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_label.add_theme_font_size_override("font_size", 14)
		target_column.add_child(action_label)
		
		# Apply health changes for this individual action
		apply_action_health_changes(action)

func apply_action_health_changes(action: GameInfo.CombatLogEntry):
	var combat = GameInfo.current_combat_log
	if not combat:
		return
	
	# Determine which health bar to affect based on player
	var health_bar = null
	if action.player == combat.player1_name:
		health_bar = player_health_bar
	else:
		health_bar = enemy_health_bar
	
	# Apply the effect
	if is_damage_action(action.action):
		animate_health_decrease(health_bar, action.factor)
	elif action.action == "heal" and action.factor > 0:
		animate_health_increase(health_bar, action.factor)



func format_combat_entry(entry: GameInfo.CombatLogEntry) -> String:
	var text = ""
	
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
		"burn damage":
			text += entry.player + " suffers " + str(entry.factor) + " burn damage!"
		"fire damage":
			text += entry.player + " takes " + str(entry.factor) + " fire damage!"
		"poison damage":
			text += entry.player + " takes " + str(entry.factor) + " poison damage!"
		"heal":
			if entry.factor > 0:
				text += entry.player + " heals for " + str(entry.factor) + " HP!"
			else:
				text += entry.player + " heals!"
		"cast spell":
			text += entry.player + " casts a spell!"
		"shield":
			text += entry.player + " raises a shield!"
		"rage":
			text += entry.player + " enters a rage!"
		"fire breath":
			text += entry.player + " breathes fire!"
		"intimidate":
			text += entry.player + " intimidates!"
		"claw strike":
			text += entry.player + " strikes with claws!"
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

func animate_health_increase(health_bar: ProgressBar, heal_amount: int):
	if heal_amount <= 0:
		return
	
	var new_health = min(health_bar.max_value, health_bar.value + heal_amount)
	
	# Create tween for smooth health bar animation
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)
	tween.tween_callback(func(): pass)  # Optional callback when animation completes

# Helper function to check if an action causes damage
func is_damage_action(action: String) -> bool:
	return action in ["hit", "burn damage", "fire damage", "poison damage", "damage", "crit hit"]

# Helper function to scroll to bottom of the log with smooth animation
func smooth_scroll_to_bottom():
	if unified_scroll:
		await get_tree().process_frame
		await get_tree().process_frame
		
		var target_value = unified_scroll.get_v_scroll_bar().max_value
		var current_value = unified_scroll.get_v_scroll_bar().value
		
		if target_value > current_value:
			var tween = create_tween()
			tween.tween_property(unified_scroll.get_v_scroll_bar(), "value", target_value, 0.4)

# Helper function to scroll to bottom of the log
func scroll_to_bottom():
	if unified_scroll:
		# Force the scroll container to update its scroll range
		unified_scroll.get_v_scroll_bar().value = unified_scroll.get_v_scroll_bar().max_value

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
		# Skip to the end - show all remaining actions instantly
		display_timer.stop()
		action_timer.stop()
		
		# Display all remaining actions
		while current_action_index < all_actions.size():
			var action_data = all_actions[current_action_index]
			
			if action_data.type == "turn_header":
				display_turn_header(action_data.turn_number)
			elif action_data.type == "individual_action":
				display_individual_action(action_data)
				
				# Apply health changes instantly (no animation)
				var action = action_data.action
				if is_damage_action(action.action):
					if action_data.player_side == "player1":
						player_health_bar.value = max(0, player_health_bar.value - action.factor)
					else:
						enemy_health_bar.value = max(0, enemy_health_bar.value - action.factor)
				elif action.action == "heal" and action.factor > 0:
					if action_data.player_side == "player1":
						player_health_bar.value = min(player_health_bar.max_value, player_health_bar.value + action.factor)
					else:
						enemy_health_bar.value = min(enemy_health_bar.max_value, enemy_health_bar.value + action.factor)
			
			current_action_index += 1
		
		if GameInfo.current_combat_log:
			combat_result.text = GameInfo.current_combat_log.final_message
		is_combat_finished = true
		skip_replay_button.text = "Replay"
		call_deferred("scroll_to_bottom")
