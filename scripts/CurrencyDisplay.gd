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

func _ready():
	# Connect to GameInfo signals
	if GameInfo:
		GameInfo.bag_slots_changed.connect(update_display)
	
	# Hide info panel initially
	if location_info_panel:
		location_info_panel.visible = false
	
	# Connect mouse signals for location hover (if this is a Panel/Control with mouse detection)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Initial update
	update_display()

func _gui_input(event: InputEvent):
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
	
	# Update gold (silver) if label exists
	if gold_label:
		gold_label.text = str(GameInfo.current_player.gold)
	
	# Update currency if label exists
	if currency_label:
		currency_label.text = str(GameInfo.current_player.currency)
	
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
