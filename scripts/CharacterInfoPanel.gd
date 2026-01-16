extends Control

# Character info panel for name, faction, and VIP selection
@export var name_input: LineEdit
@export var order_button: Button
@export var guild_button: Button
@export var companions_button: Button
@export var vip_yes_button: Button
@export var vip_no_button: Button
@export var next_button: Button

# Store character creation data
var character_name: String = ""
var faction: int = 0  # 0=none, 1=Order, 2=Guild, 3=Companions
var is_vip: bool = false

signal next_pressed

func _ready():
	next_button.pressed.connect(_on_next_pressed)
	order_button.pressed.connect(_on_faction_selected.bind(1))
	guild_button.pressed.connect(_on_faction_selected.bind(2))
	companions_button.pressed.connect(_on_faction_selected.bind(3))
	vip_yes_button.pressed.connect(_on_vip_selected.bind(true))
	vip_no_button.pressed.connect(_on_vip_selected.bind(false))

func _on_faction_selected(faction_id: int):
	faction = faction_id
	print("Faction selected: ", faction_id)

func _on_vip_selected(vip: bool):
	is_vip = vip
	print("VIP selected: ", vip)

func _on_next_pressed():
	character_name = name_input.text.strip_edges()
	
	if character_name == "":
		print("Name is required!")
		return
	
	if faction == 0:
		print("Faction is required!")
		return
	
	print("Character info complete: ", character_name, " Faction: ", faction, " VIP: ", is_vip)
	next_pressed.emit()

func get_character_data() -> Dictionary:
	return {
		"name": character_name,
		"faction": faction,
		"vip": is_vip
	}
