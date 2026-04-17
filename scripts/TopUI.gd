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
	if time_label:
		time_label.text = server_time

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
		var mushrooms = int(GameInfo.lobby_data.mushrooms)
		currency_label.text = str(mushrooms)
	
	# Update location
	var location_id = GameInfo.current_player.location
	var location = GameInfo.settlements_db.get_location_by_id(location_id) if GameInfo.settlements_db else null
	var server_time = _get_server_time_string()
	
	if time_label:
		time_label.text = server_time
	
	# Update day label
	if day_label and GameInfo.current_player:
		day_label.text = "Day " + str(GameInfo.current_player.server_day)
	
	# Update location description
	if location_description_label and location:
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
		health_bar.get_node("HealthLabel").text = str(current_health) + " / " + str(max_health)

func _get_server_time_string() -> String:
	if not GameInfo.current_player:
		return "00:00"
	
	# Get current time (we could add timezone conversion here if needed)
	var current_unix = Time.get_unix_time_from_system()
	var time_dict = Time.get_datetime_dict_from_unix_time(int(current_unix))
	
	return "%02d:%02d" % [time_dict.hour, time_dict.minute]
