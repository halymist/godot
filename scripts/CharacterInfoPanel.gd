extends Control

# Character info panel for name, faction, and VIP selection
@export var name_input: LineEdit
@export var order_button: Button
@export var guild_button: Button
@export var companions_button: Button
@export var vip_yes_button: Button
@export var vip_no_button: Button
@export var next_button: Button
@export var back_button: Button
@export var server_info_label: Label

# Description labels
@export var faction_desc_label: Label
@export var vip_desc_label: Label
@export var name_error_label: Label

# Descriptions
@export_group("Faction Descriptions")
@export_multiline var order_description: String = "The Order values discipline and honor. Defenders of the realm."
@export_multiline var guild_description: String = "The Guild prizes wealth and trade. Masters of commerce."
@export_multiline var companions_description: String = "The Companions seek freedom and adventure. Warriors of the wild."

@export_group("Patron Description")
@export_multiline var patron_description: String = "• Exclusive perks and benefits\n• Priority support\n• Special rewards"
@export_multiline var commoner_description: String = "• Standard account\n• Core features available\n• Free to play"

# Store character creation data
var character_name: String = ""
var faction: int = 1  # 1=Order, 2=Guild, 3=Companions (Order pre-selected)
var is_vip: bool = false
var _server_name: String = ""
var _server_day: int = 0

signal next_pressed
signal back_pressed

func _ready():
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	order_button.pressed.connect(_on_faction_selected.bind(1))
	guild_button.pressed.connect(_on_faction_selected.bind(2))
	companions_button.pressed.connect(_on_faction_selected.bind(3))
	
	vip_yes_button.pressed.connect(_on_vip_selected.bind(true))
	vip_no_button.pressed.connect(_on_vip_selected.bind(false))
	
	_update_descriptions()
	_update_server_info()

func _on_faction_selected(faction_id: int):
	faction = faction_id
	_update_descriptions()

func _on_vip_selected(vip: bool):
	is_vip = vip
	_update_descriptions()

func _update_descriptions():
	# Update faction description
	if faction_desc_label:
		match faction:
			1:
				faction_desc_label.text = order_description
			2:
				faction_desc_label.text = guild_description
			3:
				faction_desc_label.text = companions_description
			_:
				faction_desc_label.text = ""
	
	# Update Patron description
	if vip_desc_label:
		if is_vip:
			vip_desc_label.text = patron_description
		else:
			vip_desc_label.text = commoner_description

func set_target_server(server_name: String, server_day: int):
	_server_name = server_name
	_server_day = max(0, server_day)
	_update_server_info()

func _update_server_info():
	if not server_info_label:
		return
	if _server_name == "":
		server_info_label.text = ""
		return
	var day_suffix := ""
	if _server_day > 0:
		day_suffix = " | Day " + str(_server_day)
	server_info_label.text = "New characters are created on " + _server_name + day_suffix

func _on_next_pressed():
	character_name = name_input.text.strip_edges()
	
	if character_name == "":
		if name_error_label:
			name_error_label.visible = true
		return
	
	if name_error_label:
		name_error_label.visible = false
	
	next_pressed.emit()

func _on_back_pressed():
	back_pressed.emit()

func get_character_data() -> Dictionary:
	return {
		"name": character_name,
		"faction": faction,
		"vip": is_vip
	}
