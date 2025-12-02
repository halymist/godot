extends HBoxContainer

# This script ensures the bag display refreshes whenever it becomes visible
# since items could have been moved in other panels (vendor, blacksmith, character)

func _ready():
	# Connect to visibility changed signal
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible and has_method("update_equip_slots"):
		# Refresh the bag display when it becomes visible
		update_equip_slots()
