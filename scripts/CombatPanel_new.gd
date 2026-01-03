extends Panel

# Combat panel that displays combat log data from GameInfo

@onready var player_icon = $CharacterArea/CharacterContainer/PlayerSection/PlayerIcon
@onready var player_health_bar = $CharacterArea/CharacterContainer/PlayerSection/PlayerHealthBar
@onready var player_label = $CharacterArea/CharacterContainer/PlayerSection/PlayerLabel
@onready var enemy_icon = $CharacterArea/CharacterContainer/EnemySection/EnemyIcon
@onready var enemy_avatar = $CharacterArea/CharacterContainer/EnemySection/EnemyAvatar  # Avatar for player opponents
@onready var enemy_texture = $CharacterArea/CharacterContainer/EnemySection/EnemyTexture  # Texture for NPC opponents
@onready var enemy_health_bar = $CharacterArea/CharacterContainer/EnemySection/EnemyHealthBar
@onready var enemy_label = $CharacterArea/CharacterContainer/EnemySection/EnemyLabel
@onready var combat_log_container = $CombatLogArea/UnifiedLogScroll/CombatLogContainer
@onready var combat_result = $CombatResult
@onready var skip_replay_button = $SkipReplayButton
@onready var unified_scroll = $CombatLogArea/UnifiedLogScroll

var current_turn_display = 0
var display_timer: Timer
var is_combat_finished = false
var current_player1_health: float
var current_player2_health: float

# For turn-based display
var organized_turns = []

func _ready():
	# Create timer for displaying combat turns
	display_timer = Timer.new()
	display_timer.wait_time = 1.5  # 1.5 seconds per turn
	display_timer.timeout.connect(_display_next_turn)
	add_child(display_timer)
	
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
	
	# Setup player1 avatar
	if player_icon and player_icon.has_method("load_cosmetics"):
		player_icon.load_cosmetics(combat.player1_avatar)
	
	# Check if enemy is NPC or player
	if combat.enemyid > 0:
		# Enemy is NPC - use enemies database
		var enemy_resource = GameInfo.enemies_db.get_enemy_by_id(combat.enemyid)
		if enemy_resource:
			enemy_label.text = enemy_resource.name
			# Show enemy texture, hide avatar
			if enemy_texture:
				enemy_texture.texture = enemy_resource.texture
				enemy_texture.visible = true
			if enemy_avatar:
				enemy_avatar.visible = false
		else:
			enemy_label.text = "Unknown Enemy"
	else:
		# Enemy is player - use player2 data
		enemy_label.text = combat.player2_name
		# Show avatar, hide texture
		if enemy_avatar and enemy_avatar.has_method("load_cosmetics"):
			enemy_avatar.load_cosmetics(combat.player2_avatar)
			enemy_avatar.visible = true
		if enemy_texture:
			enemy_texture.visible = false
	
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
	
	# Reset state
	current_turn_display = 0
	is_combat_finished = false
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
		
		# Separate actions by player (1 = player1, 2 = player2/enemy)
		for entry in turn_entries:
			if entry.player == 1:
				turn_data.player1_actions.append(entry)
			else:
				turn_data.player2_actions.append(entry)
		
		organized_turns.append(turn_data)

func _display_next_turn():
	if current_turn_display >= organized_turns.size():
		display_timer.stop()
		combat_result.text = GameInfo.current_combat_log.final_message if GameInfo.current_combat_log else "Combat Complete"
		is_combat_finished = true
		skip_replay_button.text = "Replay"
		call_deferred("scroll_to_bottom")
		return
	
	var turn_data = organized_turns[current_turn_display]
	create_turn_display(turn_data)
	
	# Apply health changes for this turn
	apply_turn_health_changes(turn_data)
	
	current_turn_display += 1
	call_deferred("scroll_to_bottom")

func create_turn_display(turn_data: Dictionary):
	# Create turn separator and title
	var turn_separator_top = HSeparator.new()
	turn_separator_top.add_theme_color_override("separator", Color(0.6, 0.4, 0.2, 0.8))
	combat_log_container.add_child(turn_separator_top)
	
	# Turn title
	var turn_title = Label.new()
	turn_title.text = "Turn " + str(turn_data.turn_number)
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
	
	# Create actions container
	var actions_container = HBoxContainer.new()
	actions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_log_container.add_child(actions_container)
	
	# Player actions column
	var player_column = VBoxContainer.new()
	player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_container.add_child(player_column)
	
	# Enemy actions column  
	var enemy_column = VBoxContainer.new()
	enemy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_container.add_child(enemy_column)
	
	# Add player actions
	for action in turn_data.player1_actions:
		var action_label = Label.new()
		action_label.text = format_combat_entry(action)
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_label.add_theme_font_size_override("font_size", 14)
		player_column.add_child(action_label)
	
	# Add enemy actions
	for action in turn_data.player2_actions:
		var action_label = Label.new()
		action_label.text = format_combat_entry(action)
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_label.add_theme_font_size_override("font_size", 14)
		enemy_column.add_child(action_label)
	
	# Add spacing after turn
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	combat_log_container.add_child(spacer)

func apply_turn_health_changes(turn_data: Dictionary):
	var combat = GameInfo.current_combat_log
	if not combat:
		return
	
	# Apply damage for player1 (left side)
	for action in turn_data.player1_actions:
		if is_damage_action(action.action):
			animate_health_decrease(player_health_bar, action.factor)
		elif action.action == "heal" and action.factor > 0:
			animate_health_increase(player_health_bar, action.factor)
	
	# Apply damage for player2 (right side)
	for action in turn_data.player2_actions:
		if is_damage_action(action.action):
			animate_health_decrease(enemy_health_bar, action.factor)
		elif action.action == "heal" and action.factor > 0:
			animate_health_increase(enemy_health_bar, action.factor)

func format_combat_entry(entry: GameInfo.CombatLogEntry) -> String:
	var combat = GameInfo.current_combat_log
	if not combat:
		return ""
	
	# Get the player name based on player number (1 or 2)
	var player_name = combat.player1_name if entry.player == 1 else (combat.player2_name if combat.enemyid == 0 else GameInfo.enemies_db.get_enemy_by_id(combat.enemyid).name)
	
	var text = ""
	
	match entry.action:
		"attack":
			text += player_name + " attacks!"
		"dodge":
			text += player_name + " dodges!"
		"hit":
			if entry.factor > 0:
				text += player_name + " takes " + str(entry.factor) + " damage!"
			else:
				text += player_name + " is hit!"
		"miss":
			text += player_name + " misses!"
		"burn damage":
			text += player_name + " suffers " + str(entry.factor) + " burn damage!"
		"fire damage":
			text += player_name + " takes " + str(entry.factor) + " fire damage!"
		"poison damage":
			text += player_name + " takes " + str(entry.factor) + " poison damage!"
		"heal":
			if entry.factor > 0:
				text += player_name + " heals for " + str(entry.factor) + " HP!"
			else:
				text += player_name + " heals!"
		"cast spell":
			text += player_name + " casts a spell!"
		"shield":
			text += player_name + " raises a shield!"
		"rage":
			text += player_name + " enters a rage!"
		"fire breath":
			text += player_name + " breathes fire!"
		"intimidate":
			text += player_name + " intimidates!"
		"claw strike":
			text += player_name + " strikes with claws!"
		_:
			text += player_name + " " + entry.action
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
		# Skip to the end - show all remaining turns instantly
		display_timer.stop()
		
		while current_turn_display < organized_turns.size():
			var turn_data = organized_turns[current_turn_display]
			create_turn_display(turn_data)
			
			# Apply health changes instantly (no animation)
			var combat = GameInfo.current_combat_log
			if combat:
				for action in turn_data.player1_actions:
					if is_damage_action(action.action):
						player_health_bar.value = max(0, player_health_bar.value - action.factor)
					elif action.action == "heal" and action.factor > 0:
						player_health_bar.value = min(player_health_bar.max_value, player_health_bar.value + action.factor)
				
				for action in turn_data.player2_actions:
					if is_damage_action(action.action):
						enemy_health_bar.value = max(0, enemy_health_bar.value - action.factor)
					elif action.action == "heal" and action.factor > 0:
						enemy_health_bar.value = min(enemy_health_bar.max_value, enemy_health_bar.value + action.factor)
			
			current_turn_display += 1
		
		if GameInfo.current_combat_log:
			combat_result.text = GameInfo.current_combat_log.final_message
		is_combat_finished = true
		skip_replay_button.text = "Replay"
		call_deferred("scroll_to_bottom")
