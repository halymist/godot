extends GridContainer
@export var talents: Array[AspectRatioContainer] = []
@export var reset_button: Button
@export var title_label: Label

func _ready():
	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
	
	# Connect to stats_changed signal to update title label
	GameInfo.stats_changed.connect(_on_stats_changed)
	
	# Initial update
	update_title_label()

func _on_stats_changed(_stats: Dictionary):
	update_title_label()

func refresh_all_talents():
	for talent in talents:
		if talent.has_method("update_button_appearance"):
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
	
	# Reset all talent nodes to 0 points and update their labels
	for talent in talents:
		talent.points = 0
		if talent.pointsLabel:
			talent.pointsLabel.text = "%d/%d" % [talent.points, talent.maxPoints]
	
	# Refresh all talent appearances
	refresh_all_talents()
	
	# Update the title label to reflect reset talents
	update_title_label()
	
	print("Reset complete - all talents reset to 0 points")