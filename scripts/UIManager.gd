extends Node
class_name UIManager

static var instance: UIManager

# Reference to all silver/gold display labels
@export var silver_labels: Array[Label] = []

# Reference to resolution manager (Game node)
@export var resolution_manager: Node

func _ready():
	instance = self
	# Initial update
	update_display()

func update_silver(amount: int):
	"""Add or subtract silver and update all displays"""
	print("UIManager.update_silver called with amount: ", amount)
	print("Current silver before: ", GameInfo.current_player.silver)
	GameInfo.current_player.silver += amount
	print("Current silver after: ", GameInfo.current_player.silver)
	update_display()

func update_display():
	"""Refresh all silver label displays"""
	print("UIManager.update_display called, silver_labels count: ", silver_labels.size())
	var silver_text = str(GameInfo.current_player.silver)
	for label in silver_labels:
		if label:
			print("Updating label to: ", silver_text)
			label.text = silver_text
		else:
			print("Warning: null label in silver_labels array")
