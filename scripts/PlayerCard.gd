extends Button

# Player card for character selection in lobby

signal character_selected(character_id: int, server_id: int)

var character_id: int = 0
var server_id: int = 0
var character_data: Dictionary = {}

@onready var name_label = $HBox/Info/NameLabel
@onready var server_label = $HBox/Info/ServerLabel
@onready var avatar = $HBox/AvatarContainer/Avatar

func _ready():
	# Connect button pressed signal
	pressed.connect(_on_pressed)

func setup(character: Dictionary, server_name: String = "", server_created_at: int = 0, srv_id: int = 0, server_day: int = 0):
	"""Setup the player card with character data and server info"""
	character_data = character
	character_id = character.get("character_id", 0)
	server_id = srv_id
	
	# Set labels
	if name_label:
		var vip_badge = " [VIP]" if character.get("vip", false) else ""
		name_label.text = character.get("name", "Unknown") + vip_badge
	
	if server_label and server_name != "":
		var day = server_day if server_day > 0 else _calculate_server_age_days(server_created_at)
		server_label.text = server_name + " (Day " + str(day) + ")"
	
	# Setup avatar with character's cosmetic IDs
	if avatar and character.has("avatar"):
		var avatar_data = character.get("avatar", [40, 48, 33, 88, 80, 0, 0, 0])
		var ids = {
			"face": avatar_data[0] if avatar_data.size() > 0 else 40,
			"hair": avatar_data[1] if avatar_data.size() > 1 else 48,
			"eyes": avatar_data[2] if avatar_data.size() > 2 else 33,
			"nose": avatar_data[3] if avatar_data.size() > 3 else 88,
			"mouth": avatar_data[4] if avatar_data.size() > 4 else 80,
			"brows": avatar_data[5] if avatar_data.size() > 5 else 0,
			"ears": avatar_data[6] if avatar_data.size() > 6 else 0,
			"special": avatar_data[7] if avatar_data.size() > 7 else 0
		}
		avatar.set_avatar_ids(ids)

func _calculate_server_age_days(server_created_at: int) -> int:
	"""Calculate number of days since server started using midnight boundaries"""
	if server_created_at == 0:
		return 0
	
	var current_unix = int(Time.get_unix_time_from_system())
	
	# Get date components for both timestamps (UTC)
	var created_date = Time.get_date_dict_from_unix_time(server_created_at)
	var current_date = Time.get_date_dict_from_unix_time(current_unix)
	
	# Convert both to day numbers for comparison
	var created_days = _date_to_days(created_date["year"], created_date["month"], created_date["day"])
	var current_days = _date_to_days(current_date["year"], current_date["month"], current_date["day"])
	
	return max(1, current_days - created_days + 1)

func _date_to_days(year: int, month: int, day: int) -> int:
	"""Convert a date to an absolute day number for comparison"""
	# Simple Julian day approximation for day difference calculation
	var a = (14 - month) / 12
	var y = year + 4800 - a
	var m = month + 12 * a - 3
	return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045

func _on_pressed():
	"""Handle button press"""
	print("Player card pressed for character ID: ", character_id, " on server: ", server_id)
	character_selected.emit(character_id, server_id)
