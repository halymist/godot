@tool
extends MarginContainer

@export var max_width: float = 300.0

@onready var label = $Label

func _ready():
	adjust_size()

func adjust_size():
	# Disable wrapping to get natural size
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	await get_tree().process_frame
	
	var natural_width = label.size.x
	
	if natural_width > max_width:
		# Text is too wide, enable wrapping and set max width
		label.custom_minimum_size.x = max_width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		# Text fits, no wrapping needed
		label.autowrap_mode = TextServer.AUTOWRAP_OFF

func set_text(new_text: String):
	label.text = new_text
	adjust_size()
