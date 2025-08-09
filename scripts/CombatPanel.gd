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

func _ready():
	# Create timer for displaying combat log entries
	display_timer = Timer.new()
	display_timer.wait_time = 1.5  # Display each entry every 1.5 seconds
	display_timer.timeout.connect(_display_next_entry)
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
	enemy_label.text = combat.player2_name
	
	# Set initial health bars
	player_health_bar.value = 100
	enemy_health_bar.value = 100
	player_health_bar.max_value = combat.player1_health
	enemy_health_bar.max_value = combat.player2_health
	player_health_bar.value = combat.player1_health
	enemy_health_bar.value = combat.player2_health
	
	# Clear existing log entries
	clear_log_containers()
	
	# Reset state
	current_turn = 0
	is_combat_finished = false
	combat_result.text = ""
	skip_replay_button.text = "Skip"
	
	if combat.combat_log.size() > 0:
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

func _display_next_entry():
	var combat = GameInfo.current_combat_log
	if not combat or current_turn >= combat.combat_log.size():
		display_timer.stop()
		combat_result.text = combat.final_message if combat else "Combat Complete"
		is_combat_finished = true
		skip_replay_button.text = "Replay"
		return
	
	var entry = combat.combat_log[current_turn]
	
	# Create log entry label
	var log_label = Label.new()
	log_label.text = format_combat_entry(entry)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_font_size_override("font_size", 14)
	
	# Add to appropriate log container
	if entry.player == combat.player1_name:
		player_log_container.add_child(log_label)
	else:
		enemy_log_container.add_child(log_label)
	
	# Update health bars if it's a damage action
	if entry.action.contains("hit") or entry.action.contains("damage"):
		update_health_from_entry(entry)
	
	current_turn += 1

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

func update_health_from_entry(entry: GameInfo.CombatLogEntry):
	var combat = GameInfo.current_combat_log
	if not combat:
		return
	
	if entry.player == combat.player1_name and entry.action.contains("hit"):
		var new_health = player_health_bar.value - entry.factor
		player_health_bar.value = max(0, new_health)
	elif entry.player == combat.player2_name and entry.action.contains("hit"):
		var new_health = enemy_health_bar.value - entry.factor
		enemy_health_bar.value = max(0, new_health)

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
		var combat = GameInfo.current_combat_log
		if combat:
			while current_turn < combat.combat_log.size():
				_display_next_entry()
			combat_result.text = combat.final_message
			is_combat_finished = true
			skip_replay_button.text = "Replay"
