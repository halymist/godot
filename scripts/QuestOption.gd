extends TextureButton

# Quest option button with icon and hover effect

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_mouse_entered():
	if not disabled:
		modulate = Color(1, 1, 1, 0.8)

func _on_mouse_exited():
	if not disabled:
		modulate = Color(1, 1, 1, 1)

func _on_button_down():
	if not disabled:
		modulate = Color(0.9, 0.9, 0.9, 0.7)

func _on_button_up():
	if not disabled:
		if get_global_mouse_position().distance_to(global_position + size / 2) < size.length() / 2:
			modulate = Color(1, 1, 1, 0.8)  # Still hovering
		else:
			modulate = Color(1, 1, 1, 1)  # Mouse left during click
