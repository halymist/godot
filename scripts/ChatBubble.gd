extends Label
class_name ChatBubble

var timer_id: int = 0
var _has_custom_bounds: bool = false
var _bounds_bottom_left: Vector2 = Vector2.ZERO
var _bounds_bottom_right: Vector2 = Vector2.ZERO

func _ready():
	visible = false

func set_message_bounds(bottom_left: Vector2, bottom_right: Vector2):
	_has_custom_bounds = true
	_bounds_bottom_left = bottom_left
	_bounds_bottom_right = bottom_right

func clear_message_bounds():
	_has_custom_bounds = false

func show_with_text(bubble_text: String, duration: float = 4.0):
	show_dialogue(bubble_text, duration)

func show_dialogue(dialogue_text: String, duration: float = 4.0, skip_animation: bool = false):
	text = dialogue_text
	
	# Get parent container size as boundary
	var max_width = 200  # Default fallback
	if _has_custom_bounds:
		max_width = int(abs(_bounds_bottom_right.x - _bounds_bottom_left.x))
		if max_width <= 0:
			max_width = 200
	elif get_parent() is Control:
		var parent_size = get_parent().size
		if parent_size.x > 10:
			max_width = parent_size.x
	
	# Measure natural text width
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var natural_width = font.get_string_size(dialogue_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	
	# Only constrain width if text is actually too wide for container
	if natural_width > max_width:
		autowrap_mode = TextServer.AUTOWRAP_WORD
		custom_minimum_size.x = max_width
	else:
		autowrap_mode = TextServer.AUTOWRAP_OFF
		custom_minimum_size.x = 0
	
	# Wait for layout to recalculate size
	await get_tree().process_frame

	# If custom bounds are configured, place bubble within those horizontal limits.
	if _has_custom_bounds:
		var left_x = min(_bounds_bottom_left.x, _bounds_bottom_right.x)
		var right_x = max(_bounds_bottom_left.x, _bounds_bottom_right.x)
		var bottom_y = max(_bounds_bottom_left.y, _bounds_bottom_right.y)

		var centered_x = (left_x + right_x - size.x) * 0.5
		position.x = clamp(centered_x, left_x, max(left_x, right_x - size.x))
		position.y = bottom_y - size.y
	
	# Show with animation if not already visible
	if not skip_animation:
		visible = true
		scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	
	# Increment timer ID to invalidate any previous timers
	timer_id += 1
	var current_timer_id = timer_id
	
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		# Only hide if this is still the active timer
		if current_timer_id == timer_id:
			hide_bubble()

func hide_bubble():
	if visible:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
		await tween.finished
		visible = false
