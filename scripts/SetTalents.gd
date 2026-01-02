extends GridContainer
@export var talents: Array[AspectRatioContainer] = []
@export var reset_button: Button
@export var title_label: Label

var talents_registered_count: int = 0

func _ready():
	reset_button.pressed.connect(_on_reset_button_pressed)
	update_title_label()
	
	# Wait for all talents to register, then refresh stats
	await get_tree().process_frame
	await get_tree().process_frame
	UIManager.instance.refresh_stats()

func _on_stats_changed(_stats: Dictionary):
	update_title_label()

func refresh_all_talents():
	for talent in talents:
		talent.update_button_appearance()

func update_title_label():
	if title_label:
		var spent_points = 0
		# Calculate total spent talent points
		for talent in GameInfo.current_player.talents:
			spent_points += talent.points
		
		title_label.text = "Talent points: %d/%d" % [spent_points, GameInfo.current_player.talent_points]

func _on_reset_button_pressed():
	# Clear all talents from GameInfo
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
