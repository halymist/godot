extends Control

# Export the labels so they can be assigned in the scene
@export var gold_label: Label
@export var currency_label: Label
@export var location_label: Label

# Location panel exports (from LocationPanel.gd)
@export var sunny_icon: Texture2D
@export var rainy_icon: Texture2D
@export var weather_icon_texture: TextureRect
@export var location_info_panel: PanelContainer
@export var location_hover_area: Control  # Optional control to detect hover on

var update_timer: Timer

func _ready():
	
	# Hide info panel initially
	if location_info_panel:
		location_info_panel.visible = false
	
	# Connect mouse signals for location hover
	if location_hover_area:
		location_hover_area.mouse_entered.connect(_on_mouse_entered)
		location_hover_area.mouse_exited.connect(_on_mouse_exited)

	# Create timer to update time display every second
	update_timer = Timer.new()
	update_timer.wait_time = 1.0
	update_timer.timeout.connect(_on_update_timer_timeout)
	add_child(update_timer)
	update_timer.start()
	
	# Connect to character changed signal
	GameInfo.character_changed.connect(_on_character_changed)
	
	# Initial update
	update_display()

func _on_character_changed():
	update_display()

func _on_mushrooms_changed(new_mushrooms: int):
	if currency_label:
		currency_label.text = str(new_mushrooms)

func _on_update_timer_timeout():
	"""Called every second to update the time display"""
	if location_label:
		var location_id = GameInfo.current_player.location if GameInfo.current_player else 1
		var village_name = GameInfo.get_village_name(location_id)
		var server_time = _get_server_time_string()
		location_label.text = "%s - %s" % [village_name, server_time]

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
	
	# Update mushrooms if label exists
	if currency_label:
		currency_label.text = str(GameInfo.current_player.mushrooms)
	
	# Update location if label exists
	if location_label:
		var location_id = GameInfo.current_player.location
		var village_name = GameInfo.get_village_name(location_id)
		var server_time = _get_server_time_string()
		
		# Format: "Krasna Ves - 14:35"
		location_label.text = "%s - %s" % [village_name, server_time]
	
	# Update weather icon
	_update_weather_icon()

func _get_server_time_string() -> String:
	if not GameInfo.current_player:
		return "00:00"
	
	# Get current time (we could add timezone conversion here if needed)
	var current_unix = Time.get_unix_time_from_system()
	var time_dict = Time.get_datetime_dict_from_unix_time(int(current_unix))
	
	return "%02d:%02d" % [time_dict.hour, time_dict.minute]

func _update_weather_icon():
	if not weather_icon_texture or not GameInfo.current_player:
		return
	
	match GameInfo.current_player.weather:
		1:  # Sunny
			weather_icon_texture.texture = sunny_icon
		2:  # Rainy
			weather_icon_texture.texture = rainy_icon
		_:
			weather_icon_texture.texture = null
