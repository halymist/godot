extends ColorRect
class_name PressHoldOverlay

## Overlay that fades out when pressed/held and fades back in when released
## Attach this script to any ColorRect overlay for press-to-reveal functionality

func _ready():
	gui_input.connect(_on_overlay_input)

func _on_overlay_input(event: InputEvent):
	"""Fade out when pressed, fade in when released"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Fade out overlay smoothly
				var tween = create_tween()
				tween.tween_property(self, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_OUT)
			else:
				# Fade in overlay smoothly
				var tween = create_tween()
				tween.tween_property(self, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_IN)
