extends Control

# Character info panel for name, faction, VIP selection, and stat allocation
@export var name_input: LineEdit
@export var order_button: Button
@export var guild_button: Button
@export var companions_button: Button
@export var vip_yes_button: Button
@export var vip_no_button: Button
@export var next_button: Button
@export var back_button: Button

# Stat allocation UI
@export var strength_label: Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
@export var points_label: Label
@export var strength_minus: Button
@export var strength_plus: Button
@export var stamina_minus: Button
@export var stamina_plus: Button
@export var agility_minus: Button
@export var agility_plus: Button
@export var luck_minus: Button
@export var luck_plus: Button

# Description labels
@export var faction_desc_label: Label
@export var vip_desc_label: Label

# Descriptions
@export_group("Faction Descriptions")
@export_multiline var order_description: String = "The Order values discipline and honor. Defenders of the realm."
@export_multiline var guild_description: String = "The Guild prizes wealth and trade. Masters of commerce."
@export_multiline var companions_description: String = "The Companions seek freedom and adventure. Warriors of the wild."

@export_group("VIP Description")
@export_multiline var vip_description: String = "VIP status grants exclusive perks and benefits."
@export_multiline var no_vip_description: String = "Standard account with core features."

# Store character creation data
var character_name: String = ""
var faction: int = 1  # 1=Order, 2=Guild, 3=Companions (Order pre-selected)
var is_vip: bool = false

# Stat allocation
var strength: int = 5
var stamina: int = 5
var agility: int = 5
var luck: int = 5
var points_remaining: int = 10

signal next_pressed
signal back_pressed

func _ready():
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	order_button.pressed.connect(_on_faction_selected.bind(1))
	guild_button.pressed.connect(_on_faction_selected.bind(2))
	companions_button.pressed.connect(_on_faction_selected.bind(3))
	
	# Prevent deselection of faction buttons
	order_button.toggled.connect(_on_faction_toggled.bind(1, order_button))
	guild_button.toggled.connect(_on_faction_toggled.bind(2, guild_button))
	companions_button.toggled.connect(_on_faction_toggled.bind(3, companions_button))
	
	vip_yes_button.pressed.connect(_on_vip_selected.bind(true))
	vip_no_button.pressed.connect(_on_vip_selected.bind(false))
	
	# Connect stat buttons
	strength_minus.pressed.connect(_on_stat_changed.bind("strength", -1))
	strength_plus.pressed.connect(_on_stat_changed.bind("strength", 1))
	stamina_minus.pressed.connect(_on_stat_changed.bind("stamina", -1))
	stamina_plus.pressed.connect(_on_stat_changed.bind("stamina", 1))
	agility_minus.pressed.connect(_on_stat_changed.bind("agility", -1))
	agility_plus.pressed.connect(_on_stat_changed.bind("agility", 1))
	luck_minus.pressed.connect(_on_stat_changed.bind("luck", -1))
	luck_plus.pressed.connect(_on_stat_changed.bind("luck", 1))
	
	_update_stat_display()
	_update_descriptions()

func _on_faction_selected(faction_id: int):
	faction = faction_id
	print("Faction selected: ", faction_id)
	_update_descriptions()

func _on_faction_toggled(toggled_on: bool, faction_id: int, button: Button):
	"""Prevent deselection of faction buttons"""
	if not toggled_on:
		# Force the button back to pressed state
		button.set_pressed_no_signal(true)

func _on_vip_selected(vip: bool):
	is_vip = vip
	print("VIP selected: ", vip)
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
	
	# Update VIP description
	if vip_desc_label:
		if is_vip:
			vip_desc_label.text = vip_description
		else:
			vip_desc_label.text = no_vip_description

func _on_stat_changed(stat_name: String, delta: int):
	var current_value = get(stat_name)
	var new_value = current_value + delta
	
	# Validate change
	if delta > 0:
		# Adding points - check if we have points remaining
		if points_remaining <= 0:
			return
	else:
		# Removing points - check if stat is above minimum (5)
		if current_value <= 5:
			return
	
	# Apply change
	set(stat_name, new_value)
	points_remaining -= delta
	_update_stat_display()

func _update_stat_display():
	strength_label.text = str(strength)
	stamina_label.text = str(stamina)
	agility_label.text = str(agility)
	luck_label.text = str(luck)
	points_label.text = "Points Remaining: " + str(points_remaining)
	
	# Enable/disable minus buttons
	strength_minus.disabled = strength <= 5
	stamina_minus.disabled = stamina <= 5
	agility_minus.disabled = agility <= 5
	luck_minus.disabled = luck <= 5
	
	# Enable/disable plus buttons
	strength_plus.disabled = points_remaining <= 0
	stamina_plus.disabled = points_remaining <= 0
	agility_plus.disabled = points_remaining <= 0
	luck_plus.disabled = points_remaining <= 0

func _on_next_pressed():
	character_name = name_input.text.strip_edges()
	
	if character_name == "":
		print("Name is required!")
		return
	
	print("Character info complete: ", character_name, " Faction: ", faction, " VIP: ", is_vip)
	print("Stats: STR:", strength, " STA:", stamina, " AGI:", agility, " LCK:", luck)
	next_pressed.emit()

func _on_back_pressed():
	back_pressed.emit()

func get_character_data() -> Dictionary:
	return {
		"name": character_name,
		"faction": faction,
		"vip": is_vip,
		"strength": strength,
		"stamina": stamina,
		"agility": agility,
		"luck": luck
	}
