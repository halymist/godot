extends TextureRect
class_name NPC

@export var npc_name: String = ""
@export var status: String = "peasant"
@export var npc_data: Dictionary = {}

@onready var click_button: Button = $ClickButton

signal npc_clicked(npc: NPC)

func _ready():
	# Connect the button press signal
	click_button.button_up.connect(_on_button_pressed)
	
	# Set default NPC texture
	var npc_texture_path = "res://assets/images/fallback/npc.png"
	if ResourceLoader.exists(npc_texture_path):
		texture = load(npc_texture_path)

func _on_button_pressed():
	npc_clicked.emit(self)
	print("Clicked NPC: ", npc_name)

func set_npc_data(data: Dictionary):
	npc_data = data
	npc_name = data.get("name", "Unknown NPC")
	
	# Set texture to npc.png
	var npc_texture_path = "res://assets/images/fallback/npc.png"
	if ResourceLoader.exists(npc_texture_path):
		texture = load(npc_texture_path)
