extends Panel

# Combat panel that displays combat messages with fade in/out

@onready var combat_background = $CombatBackground
@onready var player_avatar = $PlayerContainer/PlayerIcon/PlayerAvatar
@onready var player_health_bar = $PlayerContainer/PlayerHealthBar
@onready var player_label = $PlayerContainer/PlayerLabel
@onready var enemy_avatar = $EnemyContainer/EnemyIcon/EnemyAvatar
@onready var enemy_health_bar = $EnemyContainer/EnemyHealthBar
@onready var enemy_label = $EnemyContainer/EnemyLabel
@onready var message_container = $MessageArea/MessageContainer
@onready var skip_replay_button = $SkipReplayButton

const MAX_MESSAGES = 3
var message_labels = []

var action_timer: Timer
var fade_timer: Timer
var is_combat_finished = false
var current_action_index = 0
var all_actions = []
var current_message_tween: Tween

func _ready():
	# Create timer for displaying actions
	action_timer = Timer.new()
	action_timer.wait_time = 1.5  # 1.5 seconds per message
	action_timer.timeout.connect(_display_next_action)
	add_child(action_timer)
	
	# Create timer for message fading
	fade_timer = Timer.new()
	fade_timer.wait_time = 1.0  # Message visible for 1 second before fading
	fade_timer.one_shot = true
	fade_timer.timeout.connect(_fade_current_message)
	add_child(fade_timer)
	
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
	
	# Update avatar cosmetics
	if GameInfo.current_player:
		player_avatar.refresh_avatar(
			GameInfo.current_player.avatar_face,
			GameInfo.current_player.avatar_hair,
			GameInfo.current_player.avatar_eyes,
			GameInfo.current_player.avatar_nose,
			GameInfo.current_player.avatar_mouth
		)
	enemy_avatar.refresh_avatar(1, 11, 21, 31, 41)
	
	# Set initial health bars
	player_health_bar.max_value = combat.player1_health
	enemy_health_bar.max_value = combat.player2_health
	player_health_bar.value = combat.player1_health
	enemy_health_bar.value = combat.player2_health
	
	# Build action list
	create_action_sequence(combat)
	
	# Reset state
	current_action_index = 0
	is_combat_finished = false
	skip_replay_button.text = "Skip"
	clear_messages()
	
	if all_actions.size() > 0:
		call_deferred("_start_action_timer")
	else:
		show_final_message(combat.final_message)

func _start_action_timer():
	if is_inside_tree():
		action_timer.start()

func create_action_sequence(combat: GameInfo.CombatResponse):
	all_actions.clear()
	
	# Add all combat log entries as individual messages
	for entry in combat.combat_log:
		all_actions.append({
			"type": "combat_action",
			"entry": entry
		})
	
	# Add final message
	all_actions.append({
		"type": "final_message",
		"message": combat.final_message
	})

func _display_next_action():
	if current_action_index >= all_actions.size():
		action_timer.stop()
		is_combat_finished = true
		skip_replay_button.text = "Replay"
		return
	
	var action_data = all_actions[current_action_index]
	
	if action_data.type == "combat_action":
		var entry = action_data.entry
		display_combat_message(entry)
		apply_action_health_changes(entry)
	elif action_data.type == "final_message":
		show_final_message(action_data.message)
	
	current_action_index += 1

func display_combat_message(entry: GameInfo.CombatLogEntry):
	var message_text = format_combat_entry(entry)
	add_message(message_text)

func add_message(text: String):
	# Create new message label
	var new_label = Label.new()
	new_label.text = text
	new_label.custom_minimum_size = Vector2(400, 0)
	new_label.add_theme_font_size_override("font_size", 16)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	new_label.modulate.a = 0
	
	# Add to container
	message_container.add_child(new_label)
	message_labels.append(new_label)
	
	# Fade in the new message
	var tween = create_tween()
	tween.tween_property(new_label, "modulate:a", 1.0, 0.3)
	
	# Remove oldest message if we exceed max
	if message_labels.size() > MAX_MESSAGES:
		var oldest_label = message_labels.pop_front()
		var fade_tween = create_tween()
		fade_tween.tween_property(oldest_label, "modulate:a", 0.0, 0.2)
		fade_tween.tween_callback(oldest_label.queue_free)

func show_final_message(message: String):
	# Clear all messages
	clear_messages()
	
	# Show final message with larger font
	var final_label = Label.new()
	final_label.text = message
	final_label.custom_minimum_size = Vector2(400, 0)
	final_label.add_theme_font_size_override("font_size", 20)
	final_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1))
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	final_label.modulate.a = 0
	
	message_container.add_child(final_label)
	message_labels.append(final_label)
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(final_label, "modulate:a", 1.0, 0.5)

func clear_messages():
	for label in message_labels:
		label.queue_free()
	message_labels.clear()

func _fade_current_message():
	pass  # No longer needed

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
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)

func animate_health_increase(health_bar: ProgressBar, heal_amount: int):
	if heal_amount <= 0:
		return
	
	var new_health = min(health_bar.max_value, health_bar.value + heal_amount)
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)

func is_damage_action(action: String) -> bool:
	return action in ["hit", "burn damage", "fire damage", "poison damage", "damage", "crit hit"]

func _on_visibility_changed():
	if visible:
		display_combat_log()

func _on_skip_replay_pressed():
	if is_combat_finished:
		# Replay the combat
		display_combat_log()
	else:
		# Skip to the end
		action_timer.stop()
		if fade_timer:
			fade_timer.stop()
		
		# Apply all remaining actions instantly
		while current_action_index < all_actions.size():
			var action_data = all_actions[current_action_index]
			
			if action_data.type == "combat_action":
				var entry = action_data.entry
				# Apply health changes instantly (no animation)
				var combat = GameInfo.current_combat_log
				if combat:
					var health_bar = null
					if entry.player == combat.player1_name:
						health_bar = player_health_bar
					else:
						health_bar = enemy_health_bar
					
					if is_damage_action(entry.action):
						health_bar.value = max(0, health_bar.value - entry.factor)
					elif entry.action == "heal" and entry.factor > 0:
						health_bar.value = min(health_bar.max_value, health_bar.value + entry.factor)
			elif action_data.type == "final_message":
				show_final_message(action_data.message)
			
			current_action_index += 1
		
		is_combat_finished = true
		skip_replay_button.text = "Replay"
