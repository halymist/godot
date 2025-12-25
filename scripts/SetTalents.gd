extends GridContainer
@export var talents: Array[AspectRatioContainer] = []
@export var reset_button: Button
@export var title_label: Label

func _ready():
	reset_button.pressed.connect(_on_reset_button_pressed)
	update_title_label()

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
	print("Reset all talents - cleared GameInfo talent data")
	
	# Deactivate all active perks and move them to the beginning of inactive list
	if GameInfo.current_player and GameInfo.current_player.perks:
		var active_perks = []
		var inactive_perks = []
		
		# Separate active and inactive perks
		for perk in GameInfo.current_player.perks:
			if perk.active:
				active_perks.append(perk)
			else:
				inactive_perks.append(perk)
		
		# Deactivate all active perks
		for perk in active_perks:
			perk.active = false
		
		# Reassign slots: active perks first, then inactive perks
		var slot_counter = 1
		for perk in active_perks:
			perk.slot = slot_counter
			slot_counter += 1
		for perk in inactive_perks:
			perk.slot = slot_counter
			slot_counter += 1
		
		print("Reset perks - deactivated %d active perks" % active_perks.size())
	
	# Reset all talent nodes to 0 points and update their labels
	for talent in talents:
		talent.points = 0
		if talent.pointsLabel:
			talent.pointsLabel.text = "%d/%d" % [talent.points, talent.maxPoints]
	
	# Refresh all talent appearances
	refresh_all_talents()
	update_title_label()
	
	# Refresh active effects and stats since perks were deactivated
	if UIManager.instance:
		UIManager.instance.refresh_active_effects()
		UIManager.instance.refresh_stats()
	
	print("Reset complete - all talents reset to 0 points")
