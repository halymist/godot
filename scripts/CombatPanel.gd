extends Panel

# Combat panel that displays combat messages with fade in/out

@onready var combat_background = $CombatBackground
@onready var player_avatar = $PlayerContainer/PlayerIcon/PlayerAvatar
@onready var player_health_bar = $PlayerContainer/PlayerHealthBar
@onready var player_label = $PlayerContainer/PlayerLabel
@onready var enemy_avatar = $EnemyContainer/EnemyIcon/EnemyAvatar
@onready var enemy_health_bar = $EnemyContainer/EnemyHealthBar
@onready var enemy_label = $EnemyContainer/EnemyLabel
@onready var message1 = $MessageOverlay/MessageContainer/Message1
@onready var message2 = $MessageOverlay/MessageContainer/Message2
@onready var message3 = $MessageOverlay/MessageContainer/Message3
@onready var skip_replay_button = $SkipReplayButton
@onready var button_label = $SkipReplayButton/Label

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
	action_timer.wait_time = 1.2  # 1.2 seconds per message
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
	
	# Add hover effects to button (not label)
	skip_replay_button.mouse_entered.connect(_on_button_hover)
	skip_replay_button.mouse_exited.connect(_on_button_unhover)
	
	# Set up message labels array
	message_labels = [message1, message2, message3]

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
	button_label.text = "Skip"
	clear_messages()
	
	if all_actions.size() > 0:
		call_deferred("_start_action_timer")
	else:
		show_final_message(combat.final_message)

func _start_action_timer():
	if is_inside_tree():
		# Small delay to let user look around before combat starts
		await get_tree().create_timer(0.5).timeout
		# Display first action immediately (no delay)
		_display_next_action()
		# Start timer for subsequent actions
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
		button_label.text = "Continue"
		# Wait a bit before allowing continue
		await get_tree().create_timer(2.0).timeout
		return
	
	var action_data = all_actions[current_action_index]
	
	if action_data.type == "combat_action":
		var entry = action_data.entry
		display_combat_message(entry)
		apply_action_health_changes(entry)
	elif action_data.type == "final_message":
		show_final_message(action_data.message)
		# Change button immediately when final message shows
		action_timer.stop()
		is_combat_finished = true
		button_label.text = "Continue"
	
	current_action_index += 1

func display_combat_message(entry: GameInfo.CombatLogEntry):
	var message_text = format_combat_entry(entry)
	add_message(message_text)

func add_message(text: String):
	# Shift messages up: message1 <- message2, message2 <- message3, message3 <- new
	message_labels[0].text = message_labels[1].text
	message_labels[1].text = message_labels[2].text
	message_labels[2].text = text

func show_final_message(message: String):
	# Clear top and bottom labels
	message_labels[0].text = ""
	message_labels[2].text = ""
	# Add final message to middle slot for vertical centering
	message_labels[1].text = message

func clear_messages():
	for label in message_labels:
		label.text = ""
		label.modulate.a = 1.0

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

func animate_health_decrease(health_bar: TextureProgressBar, damage: int):
	if damage <= 0:
		return
	
	var new_health = max(0, health_bar.value - damage)
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)

func animate_health_increase(health_bar: TextureProgressBar, heal_amount: int):
	if heal_amount <= 0:
		return
	
	var new_health = min(health_bar.max_value, health_bar.value + heal_amount)
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)

func is_damage_action(action: String) -> bool:
	return action in ["hit", "burn damage", "fire damage", "poison damage", "damage", "crit hit"]

func _on_button_hover():
	skip_replay_button.modulate = Color(1.2, 1.2, 1.2)  # Brighten button on hover

func _on_button_unhover():
	skip_replay_button.modulate = Color(1, 1, 1)  # Reset to normal

func _on_visibility_changed():
	if visible:
		display_combat_log()

func _on_skip_replay_pressed():
	if is_combat_finished:
		# Continue after combat - close combat panel or return to village
		self.visible = false
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
		button_label.text = "Continue"
