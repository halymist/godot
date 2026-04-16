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

func setup(character: Dictionary, server_name: String = "", server_created_at: int = 0, srv_id: int = 0):
	"""Setup the player card with character data and server info"""
	character_data = character
	character_id = character.get("character_id", 0)
	server_id = srv_id
	
	# Set labels
	if name_label:
		var vip_badge = " [VIP]" if character.get("vip", false) else ""
		name_label.text = character.get("name", "Unknown") + vip_badge
	
	if server_label and server_name != "":
		var server_age_days = _calculate_server_age_days(server_created_at)
		server_label.text = server_name + " (Day " + str(server_age_days) + ")"
	
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
	"""Calculate number of days since server started from unix timestamp"""
	if server_created_at == 0:
		return 0
	
	var current_unix = Time.get_unix_time_from_system()
	var seconds_passed = current_unix - server_created_at
	var days_passed = int(seconds_passed / 86400.0)
	
	return max(1, days_passed)  # At least 1 day

func _on_pressed():
	"""Handle button press"""
	print("Player card pressed for character ID: ", character_id, " on server: ", server_id)
	character_selected.emit(character_id, server_id)
