extends Panel
class_name QuestPanel

@export var quest_name_label: Label
@export var quest_dialogue_label: Label
@export var background_button: Button

var current_quest_data: Dictionary = {}

signal quest_panel_closed()

func _ready():
	if background_button:
		background_button.pressed.connect(_on_background_pressed)

func _on_background_pressed():
	hide_panel()

func show_quest(quest_data: Dictionary):
	current_quest_data = quest_data
	
	if quest_name_label:
		quest_name_label.text = quest_data.get("questname", "Unknown Quest")
	
	if quest_dialogue_label:
		quest_dialogue_label.text = quest_data.get("dialogue", "No dialogue available.")
	
	visible = true

func hide_panel():
	visible = false
	quest_panel_closed.emit()
