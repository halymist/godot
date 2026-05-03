extends Button

const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")

@export var name_label: Label
@export var description_label: Label
@export var upgrade_button: Button
@export var title_label: Label
@export var talents_container: GridContainer

var talent_ref: Node = null

func _ready():
	pressed.connect(_on_button_pressed)
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	visible = false
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	talents_container.update_title_label()

func set_talent_data(talent_name: String, description: String, factor: float, points: int, max_points: int, eligible_for_upgrade: bool, talent_reference: Node = null):
	visible = true
	
	# Create the name with level display
	var level_text = ""
	if points >= max_points:
		level_text = " (MAX)"
	elif points > 0:
		level_text = " (Lv. " + str(points) + ")"
	else:
		level_text = " (Lv. 0)"
	
	name_label.text = talent_name + level_text
	
	# Replace '*' (or '*%') with current/next values from talent factor.
	var processed_description = description
	if factor != 0 and ("*%" in description or "*" in description):
		var current_effect = int(points * factor)
		if points >= max_points:
			processed_description = EFFECT_FORMATTER.format_with_factor(description, current_effect)
		else:
			var next_points = min(points + 1, max_points)
			var next_effect = int(next_points * factor)
			processed_description = EFFECT_FORMATTER.format_with_progress(description, current_effect, next_effect)
	
	description_label.text = processed_description
	talent_ref = talent_reference
	
	if eligible_for_upgrade:
		upgrade_button.visible = true
	else:
		upgrade_button.visible = false

func _on_button_pressed():
	# Hide this sub-overlay
	visible = false

func _on_upgrade_button_pressed():
	Websocket.add_talent(talent_ref.talentID)
	talent_ref.upgrade_talent()
	talents_container.update_title_label()
	visible = false
