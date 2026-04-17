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
var combat_session_id: int = 0  # Incremented each prepare to invalidate stale coroutines
var tracked_player_hp: int = 0  # Actual player HP (not tween-animated)
var tracked_enemy_hp: int = 0   # Actual enemy HP (not tween-animated)
var player_hp_tween: Tween
var enemy_hp_tween: Tween

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
	
	# Update player avatar cosmetics from combat data
	if combat.player_avatar.size() >= 5:
		var ids = {
			"face": combat.player_avatar[0],
			"hair": combat.player_avatar[1],
			"eyes": combat.player_avatar[2],
			"nose": combat.player_avatar[3],
			"mouth": combat.player_avatar[4],
			"brows": combat.player_avatar[5] if combat.player_avatar.size() > 5 else 0,
			"ears": combat.player_avatar[6] if combat.player_avatar.size() > 6 else 0,
			"special": combat.player_avatar[7] if combat.player_avatar.size() > 7 else 0
		}
		player_avatar.set_avatar_ids(ids)
	
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
		# Use enemy avatar from combat data
		if combat.enemy_avatar.size() >= 5:
			var ids = {
				"face": combat.enemy_avatar[0],
				"hair": combat.enemy_avatar[1],
				"eyes": combat.enemy_avatar[2],
				"nose": combat.enemy_avatar[3],
				"mouth": combat.enemy_avatar[4],
				"brows": combat.enemy_avatar[5] if combat.enemy_avatar.size() > 5 else 0,
				"ears": combat.enemy_avatar[6] if combat.enemy_avatar.size() > 6 else 0,
				"special": combat.enemy_avatar[7] if combat.enemy_avatar.size() > 7 else 0
			}
			enemy_avatar.set_avatar_ids(ids)
		else:
			enemy_avatar.set_avatar_ids({"face": 40, "hair": 48, "eyes": 33, "nose": 88, "mouth": 80})
	
	# Invalidate any stale coroutines from previous combat
	combat_session_id += 1
	
	# Set initial health bars and labels
	player_health_bar.max_value = combat.player_max_hp
	enemy_health_bar.max_value = combat.enemy_max_hp
	var hp_lost = int(combat.player_depleted_health)
	var starting_player_hp = max(0, combat.player_max_hp - hp_lost)
	player_health_bar.value = starting_player_hp
	enemy_health_bar.value = combat.enemy_max_hp
	tracked_player_hp = starting_player_hp
	tracked_enemy_hp = combat.enemy_max_hp
	
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
		var my_session = combat_session_id
		# Small delay to let user look around before combat starts
		await get_tree().create_timer(0.5).timeout
		# Bail out if a new combat was prepared or panel hidden
		if combat_session_id != my_session:
			return
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
		return
	
	var action_data = all_actions[current_action_index]
	current_action_index += 1
	
	if action_data.type == "combat_action":
		var entry = action_data.entry
		display_combat_message(entry)
		apply_action_health_changes(entry)
		# Check tracked HP (not tween-animated bar value) for instant 0-HP detection
		if tracked_player_hp <= 0 or tracked_enemy_hp <= 0:
			_skip_to_end()
			return
	elif action_data.type == "final_message":
		show_final_message(action_data.message)
		action_timer.stop()
		is_combat_finished = true
		skip_replay_button.text = "Continue"

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
	
	# Bleed tick (no trigger_type) = self-damage
	if action.action == "bleed" and action.trigger_type == "":
		if action.character_id == combat.player_id:
			tracked_player_hp = max(0, tracked_player_hp - action.factor)
			animate_health_decrease(player_health_bar, action.factor)
		else:
			tracked_enemy_hp = max(0, tracked_enemy_hp - action.factor)
			animate_health_decrease(enemy_health_bar, action.factor)
		return

	# Damage dealt to opponent
	if is_damage_action(action.action):
		if action.character_id == combat.player_id:
			tracked_enemy_hp = max(0, tracked_enemy_hp - action.factor)
			animate_health_decrease(enemy_health_bar, action.factor)
		else:
			tracked_player_hp = max(0, tracked_player_hp - action.factor)
			animate_health_decrease(player_health_bar, action.factor)
	elif action.action == "heal" and action.factor > 0:
		if action.character_id == combat.player_id:
			tracked_player_hp = min(int(player_health_bar.max_value), tracked_player_hp + action.factor)
			animate_health_increase(player_health_bar, action.factor)
		else:
			tracked_enemy_hp = min(int(enemy_health_bar.max_value), tracked_enemy_hp + action.factor)
			animate_health_increase(enemy_health_bar, action.factor)

func format_combat_entry(entry: GameInfo.CombatLogEntry) -> String:
	var text = ""
	var combat = GameInfo.current_combat_log
	if not combat:
		return ""
	
	var actor_name = ""
	if entry.character_id == combat.player_id:
		actor_name = combat.player_name
	else:
		actor_name = combat.enemy_name

	var opponent_name = ""
	if entry.character_id == combat.player_id:
		opponent_name = combat.enemy_name
	else:
		opponent_name = combat.player_name

	match entry.action:
		"attack":
			text = actor_name + " attacks for " + str(entry.factor) + " damage!"
		"crit":
			text = actor_name + " crits for " + str(entry.factor) + " damage!"
		"dodge":
			text = opponent_name + " dodges!"
		"damage":
			text = actor_name + " deals " + str(entry.factor) + " damage!"
		"heal":
			if entry.factor > 0:
				text = actor_name + " heals for " + str(entry.factor) + " HP!"
			else:
				text = actor_name + " heals!"
		"stun":
			text = actor_name + " stuns " + opponent_name + "!"
		"stunned":
			text = actor_name + " is stunned!"
		"bleed":
			if entry.trigger_type == "":
				text = actor_name + " bleeds for " + str(entry.factor) + " damage!"
			else:
				text = actor_name + " applies " + str(entry.factor) + " bleed!"
		"counterattack":
			text = actor_name + " counterattacks for " + str(entry.factor) + " damage!"
		"buff":
			text = actor_name + " gains a buff!"
		"buff_expire":
			text = actor_name + "'s buff expires."
		_:
			text = actor_name + " " + entry.action
	return text

func animate_health_decrease(health_bar: TextureProgressBar, damage: int):
	if damage <= 0:
		return
	
	var new_health = max(0, health_bar.value - damage)
	
	# Kill previous tween for this bar
	if health_bar == player_health_bar and player_hp_tween:
		player_hp_tween.kill()
	elif health_bar == enemy_health_bar and enemy_hp_tween:
		enemy_hp_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)
	
	if health_bar == player_health_bar:
		player_hp_tween = tween
	elif health_bar == enemy_health_bar:
		enemy_hp_tween = tween
	
	# Update health label
	var health_label = health_bar.get_node_or_null("HealthLabel")
	if health_label:
		update_health_label(health_label, new_health)

func animate_health_increase(health_bar: TextureProgressBar, heal_amount: int):
	if heal_amount <= 0:
		return
	
	var new_health = min(health_bar.max_value, health_bar.value + heal_amount)
	
	# Kill previous tween for this bar
	if health_bar == player_health_bar and player_hp_tween:
		player_hp_tween.kill()
	elif health_bar == enemy_health_bar and enemy_hp_tween:
		enemy_hp_tween.kill()
	
	var tween = create_tween()
	tween.tween_property(health_bar, "value", new_health, 0.5)
	
	if health_bar == player_health_bar:
		player_hp_tween = tween
	elif health_bar == enemy_health_bar:
		enemy_hp_tween = tween
	
	# Update health label
	var health_label = health_bar.get_node_or_null("HealthLabel")
	if health_label:
		update_health_label(health_label, new_health)

func is_damage_action(action: String) -> bool:
	return action in ["attack", "crit", "counterattack", "damage"]

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
		else:
			start_combat_playback()
	elif not visible:
		# Panel hidden — stop all playback so old combat doesn't leak
		if action_timer:
			action_timer.stop()
		if fade_timer:
			fade_timer.stop()

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
	
	# Kill any running health bar tweens
	if player_hp_tween:
		player_hp_tween.kill()
		player_hp_tween = null
	if enemy_hp_tween:
		enemy_hp_tween.kill()
		enemy_hp_tween = null
	
	# Apply all remaining actions instantly
	while current_action_index < all_actions.size():
		var action_data = all_actions[current_action_index]
		
		if action_data.type == "combat_action":
			var entry = action_data.entry
			# Apply health changes instantly (no animation)
			var combat = GameInfo.current_combat_log
			if combat:
				# Bleed tick (self-damage)
				if entry.action == "bleed" and entry.trigger_type == "":
					if entry.character_id == combat.player_id:
						tracked_player_hp = max(0, tracked_player_hp - entry.factor)
						player_health_bar.value = tracked_player_hp
						update_health_label(player_health_label, tracked_player_hp)
					else:
						tracked_enemy_hp = max(0, tracked_enemy_hp - entry.factor)
						enemy_health_bar.value = tracked_enemy_hp
						update_health_label(enemy_health_label, tracked_enemy_hp)
				elif entry.character_id == combat.player_id:
					if is_damage_action(entry.action):
						tracked_enemy_hp = max(0, tracked_enemy_hp - entry.factor)
						enemy_health_bar.value = tracked_enemy_hp
						update_health_label(enemy_health_label, tracked_enemy_hp)
					elif entry.action == "heal" and entry.factor > 0:
						tracked_player_hp = min(int(player_health_bar.max_value), tracked_player_hp + entry.factor)
						player_health_bar.value = tracked_player_hp
						update_health_label(player_health_label, tracked_player_hp)
				else:
					if is_damage_action(entry.action):
						tracked_player_hp = max(0, tracked_player_hp - entry.factor)
						player_health_bar.value = tracked_player_hp
						update_health_label(player_health_label, tracked_player_hp)
					elif entry.action == "heal" and entry.factor > 0:
						tracked_enemy_hp = min(int(enemy_health_bar.max_value), tracked_enemy_hp + entry.factor)
						enemy_health_bar.value = tracked_enemy_hp
						update_health_label(enemy_health_label, tracked_enemy_hp)
		elif action_data.type == "final_message":
			show_final_message(action_data.message)
		
		current_action_index += 1
	
	# Set final health bar values explicitly
	player_health_bar.value = tracked_player_hp
	enemy_health_bar.value = tracked_enemy_hp
	update_health_label(player_health_label, tracked_player_hp)
	update_health_label(enemy_health_label, tracked_enemy_hp)
	
	is_combat_finished = true
	skip_replay_button.text = "Continue"
	# Make sure final message is visible
	if all_actions.size() > 0 and all_actions[-1].type == "final_message":
		show_final_message(all_actions[-1].message)
