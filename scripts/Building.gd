extends TextureRect
class_name Building

@export var building_id: String = ""
@export var building_name: String = ""
@export var interior_texture: Texture2D
@export var interior_background: TextureRect  # Direct reference to interior background

@onready var click_button: Button = $ClickButton

signal building_clicked(building_id: String, interior_background: TextureRect, interior_texture: Texture2D)

func _ready():
	# Connect the button press signal
	click_button.button_up.connect(_on_button_pressed)

func _on_button_pressed():
	building_clicked.emit(building_id, interior_background, interior_texture)
