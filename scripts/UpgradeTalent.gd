extends Button

@export var name_label: Label
@export var description_label: Label
@export var upgrade_button: Button
@export var title_label: Label
@export var talents_container: GridContainer

var talent_ref: Node = null  # Reference to the talent that opened this dialog

func _ready():
	talents_container.update_title_label()
	visible = false
	pressed.connect(_on_button_pressed)
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)

func set_talent_data(talent_name: String, description: String, factor: float, points: int, max_points: int, eligible_for_upgrade: bool, talent_reference: Node = null):
	visible = true
	name_label.text = talent_name
	description_label.text = description
	talent_ref = talent_reference
	if eligible_for_upgrade:
		upgrade_button.visible = true
	else:
		upgrade_button.visible = false

func _on_button_pressed():
	visible = false

func _on_upgrade_button_pressed():
	print("Upgrade button pressed for talent: ", name_label.text)
	talent_ref.upgrade_talent()
	talents_container.update_title_label()  # Refresh the title after upgrading
	visible = false
