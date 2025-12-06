extends ScrollContainer

var dragging = false
var drag_start_position = Vector2.ZERO
var scroll_start_position = Vector2.ZERO
var last_drag_velocity = Vector2.ZERO
var velocity = Vector2.ZERO
var last_mouse_position = Vector2.ZERO
var friction = 0.9  # Lower = more friction, stops faster

func _ready():
	pass

func _process(delta):
	# Apply inertia when not dragging
	if not dragging and velocity.length() > 0.5:
		scroll_horizontal += int(velocity.x)
		scroll_vertical += int(velocity.y)
		velocity *= friction
	else:
		velocity = Vector2.ZERO

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start_position = event.position
				last_mouse_position = event.position
				scroll_start_position = Vector2(scroll_horizontal, scroll_vertical)
				velocity = Vector2.ZERO
			else:
				dragging = false
				velocity = last_drag_velocity
	
	elif event is InputEventMouseMotion:
		if dragging:
			var drag_delta = drag_start_position - event.position
			scroll_horizontal = int(scroll_start_position.x + drag_delta.x)
			scroll_vertical = int(scroll_start_position.y + drag_delta.y)
			
			# Calculate velocity for inertia
			last_drag_velocity = last_mouse_position - event.position
			last_mouse_position = event.position

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			drag_start_position = event.position
			last_mouse_position = event.position
			scroll_start_position = Vector2(scroll_horizontal, scroll_vertical)
			velocity = Vector2.ZERO
		else:
			dragging = false
			velocity = last_drag_velocity
	
	elif event is InputEventScreenDrag:
		if dragging:
			var drag_delta = drag_start_position - event.position
			scroll_horizontal = int(scroll_start_position.x + drag_delta.x)
			scroll_vertical = int(scroll_start_position.y + drag_delta.y)
			
			# Calculate velocity for inertia
			last_drag_velocity = last_mouse_position - event.position
			last_mouse_position = event.position
