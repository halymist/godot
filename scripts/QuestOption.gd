extends Button

# Quest option button with icon and hover effect

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Set initial opacity
	modulate.a = 1.0

func _on_mouse_entered():
	# Increase opacity on hover
	modulate.a = 0.7

func _on_mouse_exited():
	# Return to normal opacity
	modulate.a = 1.0
