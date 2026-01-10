extends GridContainer
@export var talents: Array[AspectRatioContainer] = []
@export var reset_button: Button
@export var title_label: Label

var talents_registered_count: int = 0
var displayed_character: GameInfo.GamePlayer = null
var is_read_only: bool = false

func _ready():
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
	
	# Connect to character changed signal
	GameInfo.character_changed.connect(_on_character_changed)
	
	# Default to player mode
	display_player()
	
	# Wait for all talents to register, then refresh stats
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_read_only:
		UIManager.instance.refresh_stats()

func _on_character_changed():
	display_player()

func _on_stats_changed(_stats: Dictionary):
	update_title_label()

func refresh_all_talents():
	for talent in talents:
		talent.update_button_appearance()

func display_player():
	"""Display current player's talents (editable)"""
	print("SetTalents: display_player called")
	displayed_character = GameInfo.current_player
	is_read_only = false
	if reset_button:
		reset_button.visible = true
	refresh_talents()

func display_character(character: GameInfo.GamePlayer, read_only: bool = true):
	"""Display any character's talents (read-only for enemies)"""
	print("SetTalents: display_character called for: ", character.name, " read_only=", read_only)
	displayed_character = character
	is_read_only = read_only
	if reset_button:
		reset_button.visible = not read_only
	refresh_talents()

func refresh_talents():
	"""Refresh all talent displays for the current character"""
	if displayed_character == null:
		print("ERROR: SetTalents: displayed_character is null")
		return
	
	print("SetTalents: Refreshing talents for: ", displayed_character.name)
	
	# Update all talent points from displayed character
	for talent_node in talents:
		if talent_node.has_method("update_from_character"):
			talent_node.update_from_character(displayed_character, is_read_only)
	
	update_title_label()

func update_title_label():
	if title_label and displayed_character:
		var spent_points = 0
		# Calculate total spent talent points
		for talent in displayed_character.talents:
			spent_points += talent.points
		
		if is_read_only:
			# Enemy mode - no available points shown
			title_label.text = "%s's Talents: %d points" % [displayed_character.name, spent_points]
		else:
			# Player mode - show available/total
			title_label.text = "Talent points: %d/%d" % [spent_points, GameInfo.current_player.talent_points]

func _on_reset_button_pressed():
	# Only allow reset for player in non-read-only mode
	if is_read_only:
		print("SetTalents: Cannot reset in read-only mode")
		return
	
	GameInfo.current_player.talents.clear()
	for talent in talents:
		talent.points = 0
		
	print("Reset all talents - cleared GameInfo talent data")
	
	# Deactivate all active perks
	for perk in GameInfo.current_player.perks:
		if perk.active:
			perk.active = false

	print("Reset perks - deactivated all active perks")
	
	# Refresh all talent appearances
	refresh_all_talents()
	update_title_label()
	
	# Refresh active effects and stats since perks were deactivated
	UIManager.instance.refresh_active_effects()
	UIManager.instance.refresh_perks()
	print("Reset complete - all talents reset to 0 points")
