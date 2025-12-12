extends Control

@export var slot_id: int = 0
@export var slot_type: String = ""

@onready var item_container = $ItemContainer

func _ready():
	if item_container:
		item_container.slot_id = slot_id
		if slot_type != "":
			item_container.slot_type = slot_type
