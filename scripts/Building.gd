extends Control
class_name Building

@export var building_id: String = ""
@export var building_name: String = ""
@export var interior_content: Control

@onready var click_button: Button = $ClickButton
@onready var hover_area: ColorRect = $HoverArea

signal building_clicked(building: Building)

func _ready():
	click_button.button_up.connect(_on_button_pressed)
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)
	resized.connect(_on_resized)

func _on_resized():
	if building_name == "Tavern":
		var parent = get_parent()
		print("Tavern resized - Parent: ", parent.name, " Parent size: ", parent.size)
		print("  Anchors: left=", anchor_left, " top=", anchor_top, " right=", anchor_right, " bottom=", anchor_bottom)
		print("  Position: ", position, " Size: ", size)

func _on_mouse_entered():
	hover_area.color = Color(1, 1, 1, 0.3)

func _on_mouse_exited():
	hover_area.color = Color(1, 1, 1, 0)

func _on_button_pressed():
	building_clicked.emit(self)
