extends Button
class_name Building

@export var building_id: String = ""
@export var building_name: String = ""
@export var building_texture: Texture2D
@export var interior_width: int = 1200

@onready var sprite: TextureRect = $BuildingSprite
@onready var label: Label = $BuildingLabel

signal building_clicked(building_id: String)

func _ready():
	# Set up the building appearance
	if building_texture:
		sprite.texture = building_texture
	
	if building_name:
		label.text = building_name
		text = ""  # Hide button text since we have label
	
	# Connect the pressed signal
	pressed.connect(_on_building_pressed)

func _on_building_pressed():
	building_clicked.emit(building_id)

func set_building_data(id: String, building_name_param: String, texture: Texture2D = null, width: int = 1200):
	building_id = id
	building_name = building_name_param
	building_texture = texture
	interior_width = width
	
	if is_inside_tree():
		_update_appearance()

func _update_appearance():
	if sprite and building_texture:
		sprite.texture = building_texture
	
	if label and building_name:
		label.text = building_name
		text = ""
