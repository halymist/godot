extends Control
class_name Utility

@export var target_panel: Panel

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
	if target_panel:
		# If this is the vendor panel, set the location-specific background
		if target_panel.name == "VendorPanel" and target_panel.has_method("set_vendor_location"):
			var location = GameInfo.current_player.location if GameInfo.current_player else 1
			target_panel.set_vendor_location(location)
		
		target_panel.visible = true
		GameInfo.set_current_panel(target_panel)
	utility_clicked.emit(self)
