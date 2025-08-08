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
	
	# Create the name with level display
	var level_text = ""
	if points >= max_points:
		level_text = " (MAX)"
	elif points > 0:
		level_text = " (Lv. " + str(points) + ")"
	else:
		level_text = " (Lv. 0)"
	
	name_label.text = talent_name + level_text
	
	# Handle factor replacement in description
	var processed_description = description
	if factor > 0 and "*" in description:
		# Replace "*" with the factor value
		processed_description = description.replace("*", str(factor))
	
	description_label.text = processed_description
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
