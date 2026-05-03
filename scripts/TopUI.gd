extends Control

# Export the labels so they can be assigned in the scene
@export var gold_label: Label
@export var currency_label: Label
@export var location_description_label: Label
@export var health_bar: TextureProgressBar
@export var time_label: Label
@export var day_label: Label

# Location panel exports
@export var location_info_panel: MarginContainer
@export var location_hover_area: Control  # Optional control to detect hover on

var update_timer: Timer

func _ready():
	
	# Hide info panel initially
	if location_info_panel:
		location_info_panel.visible = false
	
	# Connect mouse signals for location hover (if assigned)
	if location_hover_area:
		location_hover_area.mouse_entered.connect(_on_mouse_entered)
		location_hover_area.mouse_exited.connect(_on_mouse_exited)

	# Create timer to update time display every second
	update_timer = Timer.new()
	update_timer.wait_time = 1.0
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	update_timer.start()
	
	# Initial update
	update_display()

func _on_update_timer_timeout():
	"""Called every second to update the time display"""
	var server_time = _get_server_time_string()
	if time_label and is_instance_valid(time_label):
		time_label.text = server_time
	if day_label and is_instance_valid(day_label):
		day_label.text = "Day " + str(_calculate_server_day())

func _on_location_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if location_info_panel:
				location_info_panel.visible = not location_info_panel.visible

func _on_mouse_entered():
	if location_info_panel:
		location_info_panel.visible = true

func _on_mouse_exited():
	if location_info_panel:
		location_info_panel.visible = false

func update_display():
	if not GameInfo.current_player:
		return
	
	# Update mushrooms (account-level, from lobby data) - ensure displayed as integer
	if currency_label and GameInfo.lobby_data.has("mushrooms"):
		if not is_instance_valid(currency_label):
			return
		var mushrooms = int(GameInfo.lobby_data.mushrooms)
		currency_label.text = str(mushrooms)
	
	# Update silver
	if gold_label and is_instance_valid(gold_label) and GameInfo.current_player:
		gold_label.text = str(GameInfo.current_player.silver)
	
	# Update location
	var location_id = GameInfo.current_player.location
	var location = GameInfo.settlements_db.get_location_by_id(location_id) if GameInfo.settlements_db else null
	var server_time = _get_server_time_string()
	
	if time_label and is_instance_valid(time_label):
		time_label.text = server_time
	
	# Update day label
	if day_label and is_instance_valid(day_label):
		day_label.text = "Day " + str(_calculate_server_day())
	
	# Update location description
	if location_description_label and is_instance_valid(location_description_label) and location:
		location_description_label.text = location.description if location.description else "No description available."

	# Update health bar
	update_health_bar()

func update_health_bar():
	"""Update the shared health bar from current player stats."""
	if not health_bar or not GameInfo.current_player:
		return

	var total_stats = GameInfo.current_player.get_total_stats()
	var max_health = total_stats.stamina * 10
	var hp_lost = int(GameInfo.current_player.depleted_health)
	var current_health = max(0, max_health - hp_lost)

	health_bar.max_value = max_health
	health_bar.value = current_health
	if health_bar.has_node("HealthLabel"):
		var health_label = health_bar.get_node("HealthLabel")
		if health_label and is_instance_valid(health_label):
			health_label.text = str(current_health) + " / " + str(max_health)

func _get_server_time_string() -> String:
	if not GameInfo.current_player:
		return "00:00"
	
	# Get current time (we could add timezone conversion here if needed)
	var current_unix = Time.get_unix_time_from_system()
	var time_dict = Time.get_datetime_dict_from_unix_time(int(current_unix))
	
	return "%d:%02d" % [time_dict.hour, time_dict.minute]

func _calculate_server_day() -> int:
	"""Calculate current server day from server_created_at timestamp"""
	var server_created_at = GameInfo.server_created_at
	if server_created_at == 0:
		return 1
	
	var current_unix = int(Time.get_unix_time_from_system())
	var created_date = Time.get_date_dict_from_unix_time(server_created_at)
	var current_date = Time.get_date_dict_from_unix_time(current_unix)
	
	var created_days = _date_to_days(created_date["year"], created_date["month"], created_date["day"])
	var current_days = _date_to_days(current_date["year"], current_date["month"], current_date["day"])
	
	return max(1, current_days - created_days + 1)

func _date_to_days(year: int, month: int, day: int) -> int:
	"""Convert a date to an absolute day number for comparison"""
	var a = (14 - month) / 12
	var y = year + 4800 - a
	var m = month + 12 * a - 3
	return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
