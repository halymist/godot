@tool
extends Panel

# Aspect ratio constraints - DISABLED
const ENABLE_CONSTRAINT: bool = false
const MAX_ASPECT_RATIO: float = 0.867  # Threshold aspect ratio (2.6/3.0)
const CONSTRAINED_ASPECT_RATIO: float = 0.733  # Target aspect ratio when constraining (2.2/3.0)

func _process(_delta):
	if ENABLE_CONSTRAINT:
		_apply_aspect_constraint()

func _apply_aspect_constraint():
	# Get parent size
	var parent = get_parent()
	if not parent:
		return
	
	var parent_width = parent.size.x
	var parent_height = parent.size.y
	
	# Prevent division by zero
	if parent_height <= 0:
		return
	
	# Calculate current aspect ratio
	var current_aspect: float = parent_width / parent_height
	
	var panel_width = parent_width
	
	# Only apply aspect ratio constraint if current aspect exceeds max
	if current_aspect > MAX_ASPECT_RATIO:
		var constrained_width = parent_height * CONSTRAINED_ASPECT_RATIO
		panel_width = min(parent_width, constrained_width)
	
	# Update panel size and position (left-aligned)
	size = Vector2(panel_width, parent_height)
	position = Vector2(0, 0)
