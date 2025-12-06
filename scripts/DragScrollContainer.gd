extends ScrollContainer

var dragging = false
var drag_start_position = Vector2.ZERO
var scroll_start_position = Vector2.ZERO

func _ready():
	pass

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start_position = event.position
				scroll_start_position = Vector2(scroll_horizontal, scroll_vertical)
			else:
				dragging = false
	
	elif event is InputEventMouseMotion:
		if dragging:
			var drag_delta = drag_start_position - event.position
			scroll_horizontal = int(scroll_start_position.x + drag_delta.x)
			scroll_vertical = int(scroll_start_position.y + drag_delta.y)

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			drag_start_position = event.position
			scroll_start_position = Vector2(scroll_horizontal, scroll_vertical)
		else:
			dragging = false
	
	elif event is InputEventScreenDrag:
		if dragging:
			var drag_delta = drag_start_position - event.position
			scroll_horizontal = int(scroll_start_position.x + drag_delta.x)
			scroll_vertical = int(scroll_start_position.y + drag_delta.y)
