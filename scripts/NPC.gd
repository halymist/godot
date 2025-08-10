extends TextureRect
class_name NPC

@export var npc_name: String = ""
@export var status: String = "peasant"
@export var npc_texture: Texture2D

@onready var click_button: Button = $ClickButton

signal npc_clicked(npc: NPC)

func _ready():
	# Connect the button press signal
	click_button.button_up.connect(_on_button_pressed)

func _on_button_pressed():
	npc_clicked.emit(self)
	print("Clicked NPC: ", npc_name)

func set_npc_data(name_text: String, status_text: String, npc_texture_param: Texture2D = null):
	npc_name = name_text
	status = status_text
	if npc_texture_param:
		npc_texture = npc_texture_param
		self.texture = npc_texture_param
