extends Control
class_name Utility

@export var target: Button

@onready var click_button: Button = $ClickButton
@onready var hover_area: ColorRect = $HoverArea

signal utility_clicked(utility: Utility)

func _ready():
	click_button.button_up.connect(_on_button_pressed)
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	hover_area.color = Color(1, 1, 1, 0.3)

func _on_mouse_exited():
	hover_area.color = Color(1, 1, 1, 0)

func _on_button_pressed():
	if target:
		# Set the location-specific background for utility panels
		if target.has_method("set_location_texture"):
			var location = GameInfo.current_player.location if GameInfo.current_player else 1
			target.set_location_texture(location)
		
		# Find the actual utility panel (child of the wrapper)
		var utility_panel = null
		if target.get_child_count() > 0:
			# Look for the actual panel node (BlacksmithPanel, VendorPanel, etc.)
			for child in target.get_children():
				if child.name.ends_with("Panel"):
					utility_panel = child
					break
		
		# Use TogglePanel's show_utility_panel method
		var game_root = get_tree().root.get_node_or_null("Game")
		var toggle_panel = game_root.find_child("Background", true, false) if game_root else null
		if toggle_panel and toggle_panel.has_method("show_utility_panel"):
			if utility_panel:
				toggle_panel.show_utility_panel(utility_panel)
			else:
				# If no panel child found, show the target itself
				target.visible = true
	utility_clicked.emit(self)
