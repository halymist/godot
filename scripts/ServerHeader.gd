extends PanelContainer

var title_label: Label = null
var _pending_title_text: String = ""

func _ready():
	title_label = get_node_or_null("Margin/Title")
	if title_label and _pending_title_text != "":
		title_label.text = _pending_title_text
		_pending_title_text = ""

func setup(server_name: String, server_created_at: int = 0, server_day: int = 0, character_count: int = 0):
	var day = server_day if server_day > 0 else _calculate_server_age_days(server_created_at)
	var count_text = "1 character" if character_count == 1 else str(character_count) + " characters"
	_apply_title_text(server_name + "  |  Day " + str(day) + "  |  " + count_text)

func _apply_title_text(text_value: String):
	var resolved_label = title_label
	if not resolved_label or not is_instance_valid(resolved_label):
		resolved_label = get_node_or_null("Margin/Title")

	if resolved_label and is_instance_valid(resolved_label):
		title_label = resolved_label
		title_label.text = text_value
		_pending_title_text = ""
		return

	_pending_title_text = text_value
	call_deferred("_apply_deferred_title_text")

func _apply_deferred_title_text():
	if _pending_title_text == "":
		return

	var resolved_label = get_node_or_null("Margin/Title")
	if not resolved_label or not is_instance_valid(resolved_label):
		return

	title_label = resolved_label
	title_label.text = _pending_title_text
	_pending_title_text = ""

func _calculate_server_age_days(server_created_at: int) -> int:
	if server_created_at == 0:
		return 0

	var current_unix = int(Time.get_unix_time_from_system())
	var elapsed_days = int(floor((current_unix - server_created_at) / 86400.0))
	return max(1, elapsed_days + 1)
