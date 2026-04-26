extends PanelContainer

@onready var title_label: Label = $Margin/Title

func setup(server_name: String, server_created_at: int = 0, server_day: int = 0, character_count: int = 0):
	var day = server_day if server_day > 0 else _calculate_server_age_days(server_created_at)
	var count_text = "1 character" if character_count == 1 else str(character_count) + " characters"
	title_label.text = server_name + "  |  Day " + str(day) + "  |  " + count_text

func _calculate_server_age_days(server_created_at: int) -> int:
	if server_created_at == 0:
		return 0

	var current_unix = int(Time.get_unix_time_from_system())
	var elapsed_days = int(floor((current_unix - server_created_at) / 86400.0))
	return max(1, elapsed_days + 1)
