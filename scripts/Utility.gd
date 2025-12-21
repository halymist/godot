extends Control
class_name Utility

@export var target: Panel

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
		print("[Utility] Button pressed for: ", target.name)
		# Set the location-specific background for utility panels
		if target.has_method("set_location_texture"):
			var location = GameInfo.current_player.location if GameInfo.current_player else 1
			target.set_location_texture(location)
		
		# Hide any currently active overlay first
		var current_overlay = GameInfo.get_current_panel_overlay()
		if current_overlay and current_overlay != target:
			current_overlay.visible = false
		
		# Show the target panel and register it as overlay in GameInfo
		target.visible = true
		GameInfo.set_current_panel_overlay(target)
	utility_clicked.emit(self)
