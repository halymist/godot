class_name CurrentPlayer
extends GameInfo.GameCurrentPlayer
# CurrentPlayer uses the GameCurrentPlayer class from GameInfo
# This is for player-specific UI and interactions

func _init(character_data: Dictionary = {}):
	super(character_data, GameInfo)  # Pass GameInfo reference to parent

# You can add CurrentPlayer-specific methods here if needed
# that are separate from the data model in GameInfo

# Example: Add UI-specific helper methods here
func get_display_name() -> String:
	return name if name != "" else "Unnamed Player"

func get_level_description() -> String:
	var total_points = 0
	for talent in talents:
		total_points += talent.points
	return "Level %d Player" % (total_points + 1)
