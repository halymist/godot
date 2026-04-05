extends TextureRect

# Combat panel that displays combat messages with fade in/out

# Signal emitted when combat finishes and player clicks continue
@onready var player_avatar = $PlayerContainer/PlayerIcon/PlayerAvatar
@onready var player_health_bar = $PlayerContainer/PlayerHealthBar
@onready var player_health_label = $PlayerContainer/PlayerHealthBar/HealthLabel
@onready var player_label = $PlayerContainer/PlayerLabel
@onready var enemy_avatar = $EnemyContainer/EnemyIcon/EnemyAvatar
@onready var enemy_texture = $EnemyContainer/EnemyIcon/EnemyTexture
@onready var enemy_health_bar = $EnemyContainer/EnemyHealthBar
@onready var enemy_health_label = $EnemyContainer/EnemyHealthBar/HealthLabel
@onready var enemy_label = $EnemyContainer/EnemyLabel
@onready var message1 = $MessageOverlay/MessageContainer/Message1
@onready var message2 = $MessageOverlay/MessageContainer/Message2
@onready var message3 = $MessageOverlay/MessageContainer/Message3
@onready var skip_replay_button = $SkipReplayButton

# Client-side victory message (will be generated based on combat results later)
var victory_message = "Victory! You defeated your opponent!"

var message_labels = []

var action_timer: Timer
var fade_timer: Timer
var is_combat_finished = false
var current_action_index = 0
var all_actions = []
var current_message_tween: Tween

var is_prepared: bool = false  # Track if combat is prepared and ready to show

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
	
	# Connect to visibility changes - only starts playback, doesn't setup
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect button signal
	skip_replay_button.pressed.connect(_on_skip_replay_pressed)
	
	# Add hover effects to button (not label)
	skip_replay_button.mouse_entered.connect(_on_button_hover)
	skip_replay_button.mouse_exited.connect(_on_button_unhover)
	
	# Set up message labels array
	message_labels = [message1, message2, message3]

func prepare_combat():
	"""Prepare all combat visuals BEFORE showing the panel. Call this before making panel visible."""
	if not GameInfo.current_combat_log:
		print("No current combat log to prepare")
		is_prepared = false
		return
	
	var combat = GameInfo.current_combat_log
	
	# Stop any existing timers from previous combat
	if action_timer:
		action_timer.stop()
	if fade_timer:
		fade_timer.stop()
	
	# Set combat background
	set_combat_background()
	
	# Set up player info
	player_label.text = combat.player_name
	
	# Update player avatar cosmetics from combat data (server sends 4 elements)
	if combat.player_avatar.size() >= 4:
		player_avatar.refresh_avatar(
			combat.player_avatar[0],
			combat.player_avatar[1],
			combat.player_avatar[2],
			combat.player_avatar[3],
			0  # Default mouth if not provided
		)
	
	# Check if enemy is NPC or player
	if combat.is_enemy_npc():
		# Enemy is NPC - use enemies database
		var enemy_lookup_id = combat.enemy_npc_id if combat.enemy_npc_id > 0 else combat.enemy_asset_id
		var enemy_resource = GameInfo.enemies_db.get_enemy_by_id(enemy_lookup_id)
		if enemy_resource:
			enemy_label.text = enemy_resource.name
			# Show enemy texture, hide avatar
			enemy_texture.texture = enemy_resource.texture
			enemy_texture.visible = true
			enemy_avatar.visible = false
		else:
			enemy_label.text = combat.enemy_name
			enemy_texture.visible = false
			enemy_avatar.visible = true
	else:
		# Enemy is player - use enemy data from combat
		enemy_label.text = combat.enemy_name
		# Show avatar, hide texture
		enemy_avatar.visible = true
		enemy_texture.visible = false
		# Use enemy avatar from combat data (server sends 4 elements)
		if combat.enemy_avatar.size() >= 4:
			enemy_avatar.refresh_avatar(
				combat.enemy_avatar[0],
				combat.enemy_avatar[1],
				combat.enemy_avatar[2],
				combat.enemy_avatar[3],
				0  # Default mouth if not provided
			)
		else:
			enemy_avatar.refresh_avatar(1, 1, 1, 1, 0)  # Fallback to defaults
	
	# Set initial health bars and labels
	player_health_bar.max_value = combat.player_max_hp
	enemy_health_bar.max_value = combat.enemy_max_hp
	var hp_lost = int(combat.player_depleted_health)
	var starting_player_hp = max(0, combat.player_max_hp - hp_lost)
	player_health_bar.value = starting_player_hp
	enemy_health_bar.value = combat.enemy_max_hp
	
	# Update health labels
	update_health_label(player_health_label, starting_player_hp)
	update_health_label(enemy_health_label, combat.enemy_max_hp)
	
	# Build action list
	create_action_sequence(combat)
	
	# Reset state
	current_action_index = 0
	is_combat_finished = false
	skip_replay_button.text = "Skip"
	clear_messages()
	
	# Mark as prepared
	is_prepared = true

func display_combat_log():
	"""Legacy method - now just calls prepare_combat and starts playback."""
	prepare_combat()
	start_combat_playback()

func start_combat_playback():
	"""Start the combat animation playback. Called after panel is visible."""
	if not GameInfo.current_combat_log:
		return
	
	var combat = GameInfo.current_combat_log
	
	if all_actions.size() > 0:
		call_deferred("_start_action_timer")
	else:
		# Build final message
		var final_msg = ""
		if combat.has_won():
			final_msg = "Victory! You defeated " + combat.enemy_name + "!"
		else:
			final_msg = "Defeat! " + combat.enemy_name + " has won."
		show_final_message(final_msg)

func _legacy_display_combat_log():
	if not GameInfo.current_combat_log:
		print("No current combat log to display")
		return
	
	var combat = GameInfo.current_combat_log
	
	# Set combat background FIRST to reduce flicker
	set_combat_background()
	
	# Set up player info
	player_label.text = combat.player_name
	


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
	
	# Add final message based on winner
	var final_msg = ""
	if combat.has_won():
		final_msg = "Victory! You defeated " + combat.enemy_name + "!"
	else:
		final_msg = "Defeat! " + combat.enemy_name + " has won."
	
	all_actions.append({
		"type": "final_message",
		"message": final_msg
	})

func _display_next_action():
	if current_action_index >= all_actions.size():
		action_timer.stop()
		is_combat_finished = true
		skip_replay_button.text = "Continue"
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
		skip_replay_button.text = "Next"
	
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
	
	# Determine which health bar to affect based on character_id
	var health_bar = null
	if action.character_id == combat.player_id:
		health_bar = player_health_bar
	else:
		health_bar = enemy_health_bar
	
	# Apply the effect - damage is dealt TO the opponent of whoever is acting
	# So if player attacks, enemy takes damage
	if is_damage_action(action.action):
		# Swap the health bar - attacker deals damage to opponent
		if action.character_id == combat.player_id:
			animate_health_decrease(enemy_health_bar, action.factor)
		else:
			animate_health_decrease(player_health_bar, action.factor)
	elif action.action == "heal" and action.factor > 0:
		animate_health_increase(health_bar, action.factor)



func format_combat_entry(entry: GameInfo.CombatLogEntry) -> String:
	var text = ""
	var combat = GameInfo.current_combat_log
	if not combat:
		return ""
	
	# Get the actor name based on character_id
	var actor_name = ""
	if entry.character_id == combat.player_id:
		actor_name = combat.player_name
	else:
		actor_name = combat.enemy_name
	
	match entry.action:
		"attacks":
			if entry.factor > 0:
				text += actor_name + " attacks for " + str(entry.factor) + " damage!"
			else:
				text += actor_name + " attacks!"
		"attack":
			text += actor_name + " attacks!"
		"dodge":
			text += actor_name + " dodges!"
		"hit":
			if entry.factor > 0:
				text += actor_name + " takes " + str(entry.factor) + " damage!"
			else:
				text += actor_name + " is hit!"
		"miss":
			text += actor_name + " misses!"
		"burn damage":
			if entry.factor > 0:
				text += actor_name + " suffers " + str(entry.factor) + " burn damage!"
			else:
				text += actor_name + " suffers burn damage!"
		"fire damage":
			if entry.factor > 0:
				text += actor_name + " takes " + str(entry.factor) + " fire damage!"
			else:
				text += actor_name + " takes fire damage!"
		"poison damage":
			if entry.factor > 0:
				text += actor_name + " takes " + str(entry.factor) + " poison damage!"
			else:
				text += actor_name + " takes poison damage!"
		"heal":
			if entry.factor > 0:
				text += actor_name + " heals for " + str(entry.factor) + " HP!"
			else:
				text += actor_name + " heals!"
		"cast spell":
			text += actor_name + " casts a spell!"
		"shield":
			text += actor_name + " raises a shield!"
		"rage":
			text += actor_name + " enters a rage!"
		"fire breath":
			if entry.factor > 0:
				text += actor_name + " breathes fire for " + str(entry.factor) + " damage!"
			else:
				text += actor_name + " breathes fire!"
		"intimidate":
			text += actor_name + " intimidates!"
		"claw strike":
			if entry.factor > 0:
				text += actor_name + " strikes with claws for " + str(entry.factor) + " damage!"
			else:
				text += actor_name + " strikes with claws!"
		_:
			text += actor_name + " " + entry.action
			if entry.factor > 0:
				text += " (" + str(entry.factor) + ")"
	
	return text

func animate_health_decrease(health_bar: TextureProgressBar, damage: int):
	if damage <= 0:
		return
	
	var new_health = max(0, health_bar.value - damage)
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)
	
	# Update health label
	var health_label = health_bar.get_node_or_null("HealthLabel")
	if health_label:
		update_health_label(health_label, new_health)

func animate_health_increase(health_bar: TextureProgressBar, heal_amount: int):
	if heal_amount <= 0:
		return
	
	var new_health = min(health_bar.max_value, health_bar.value + heal_amount)
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)
	
	# Update health label
	var health_label = health_bar.get_node_or_null("HealthLabel")
	if health_label:
		update_health_label(health_label, new_health)

func is_damage_action(action: String) -> bool:
	return action in ["attacks", "hit", "burn damage", "fire damage", "poison damage", "damage", "crit hit"]

func update_health_label(label: Label, current: float):
	"""Update health label to show current health value"""
	label.text = str(int(current))

func _on_button_hover():
	skip_replay_button.modulate = Color(1.2, 1.2, 1.2)  # Brighten button on hover

func _on_button_unhover():
	skip_replay_button.modulate = Color(1, 1, 1)  # Reset to normal

func set_combat_background():
	"""Set the combat background texture based on current location"""
	var location = GameInfo.current_player.location if GameInfo.current_player else 1
	
	# Get location data from settlements database
	var location_data = GameInfo.settlements_db.get_location_by_id(location) if GameInfo.settlements_db else null
	if location_data and location_data.arena_background:
		texture = location_data.arena_background

func _on_visibility_changed():
	if visible and is_prepared:
		# Panel is now visible and was prepared - start playback
		is_prepared = false
		# If skip combat is enabled, skip straight to result
		if SettingsManager.get_setting("gameplay", "skip_combat", false):
			_skip_to_end()
			call_deferred("_navigate_after_combat")
		else:
			start_combat_playback()

func _on_skip_replay_pressed():
	if is_combat_finished:
		_navigate_after_combat()
	else:
		# Skip to the end
		_skip_to_end()

func _navigate_after_combat():
	# If combat came from expedition, continue to next slide
	if GameInfo.pending_expedition_slide_id_after_combat > 0:
		var next_slide_id = GameInfo.pending_expedition_slide_id_after_combat
		GameInfo.pending_expedition_slide_id_after_combat = 0
		if UIManager.instance and UIManager.instance.expedition_panel:
			UIManager.instance.show_panel(UIManager.instance.expedition_panel)
			UIManager.instance.expedition_panel.receive_next_slide(next_slide_id)
		return

	# If expedition failed after combat, show placeholder
	if GameInfo.pending_expedition_failure_message != "":
		var failure_message = GameInfo.pending_expedition_failure_message
		GameInfo.pending_expedition_failure_message = ""
		if UIManager.instance and UIManager.instance.expedition_panel:
			UIManager.instance.show_panel(UIManager.instance.expedition_panel)
			UIManager.instance.expedition_panel.handle_expedition_failed(failure_message)
		return

	# Navigate using UIManager
	var on_quest = GameInfo.current_player.traveling_destination != null
	
	if on_quest:
		# Show quest panel
		UIManager.instance.show_panel(UIManager.instance.quest)
	else:
		# Toggle to home panel
		UIManager.instance.handle_home_button()

func _skip_to_end():
	"""Skip all remaining combat actions and show the final result."""
	if action_timer:
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
				# Determine which health bar based on character_id
				if entry.character_id == combat.player_id:
					# Player is the attacker, so enemy takes damage
					if is_damage_action(entry.action):
						enemy_health_bar.value = max(0, enemy_health_bar.value - entry.factor)
						update_health_label(enemy_health_label, enemy_health_bar.value)
					elif entry.action == "heal" and entry.factor > 0:
						player_health_bar.value = min(player_health_bar.max_value, player_health_bar.value + entry.factor)
						update_health_label(player_health_label, player_health_bar.value)
				else:
					# Enemy is the attacker, so player takes damage
					if is_damage_action(entry.action):
						player_health_bar.value = max(0, player_health_bar.value - entry.factor)
						update_health_label(player_health_label, player_health_bar.value)
					elif entry.action == "heal" and entry.factor > 0:
						enemy_health_bar.value = min(enemy_health_bar.max_value, enemy_health_bar.value + entry.factor)
						update_health_label(enemy_health_label, enemy_health_bar.value)
		elif action_data.type == "final_message":
			show_final_message(action_data.message)
		
		current_action_index += 1
	
	is_combat_finished = true
	skip_replay_button.text = "Continue"
