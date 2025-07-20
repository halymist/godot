extends Button

@export var active_panel: Panel
@export var inactive_panel: Panel

func _ready():
	pressed.connect(_on_button_pressed)
	visible = false


func _on_button_pressed():
	visible = false
