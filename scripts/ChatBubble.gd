extends Label
class_name ChatBubble

var timer_id: int = 0
var _has_custom_bounds: bool = false
# Two opposite corners of the backend msg_rect, stored as top-left percentage corners.
var _bounds_corner_a: Vector2 = Vector2.ZERO
var _bounds_corner_b: Vector2 = Vector2.ZERO

func _ready():
	z_index = 20
	visible = false

func set_message_bounds(corner_a: Vector2, corner_b: Vector2):
	_has_custom_bounds = true
	_bounds_corner_a = corner_a
	_bounds_corner_b = corner_b

func clear_message_bounds():
	_has_custom_bounds = false

func show_with_text(bubble_text: String, duration: float = 4.0):
	show_dialogue(bubble_text, duration)

func _percent_bounds_to_parent_local() -> Rect2:
	var parent_control = get_parent() as Control
	if not parent_control:
		return Rect2()

	var bounds_control: Control = parent_control
	if parent_control.has_node("ImageArea"):
		var image_area = parent_control.get_node("ImageArea") as Control
		if image_area:
			bounds_control = image_area

	var bounds_size := bounds_control.size
	if bounds_size.x <= 0.0 or bounds_size.y <= 0.0:
		return Rect2()

	var left: float = min(_bounds_corner_a.x, _bounds_corner_b.x) / 100.0 * bounds_size.x
	var top: float = min(_bounds_corner_a.y, _bounds_corner_b.y) / 100.0 * bounds_size.y
	var width: float = abs(_bounds_corner_b.x - _bounds_corner_a.x) / 100.0 * bounds_size.x
	var height: float = abs(_bounds_corner_b.y - _bounds_corner_a.y) / 100.0 * bounds_size.y
	var rect_position := Vector2(left, top)
	if bounds_control != parent_control:
		rect_position += bounds_control.position

	return Rect2(rect_position, Vector2(width, height))

func show_dialogue(dialogue_text: String, duration: float = 4.0, skip_animation: bool = false):
	text = dialogue_text

	# Compute the panel-local rect we are allowed to draw inside.
	var bound_rect: Rect2 = Rect2()
	var has_rect := false
	if _has_custom_bounds:
		bound_rect = _percent_bounds_to_parent_local()
		has_rect = bound_rect.size.x > 1 and bound_rect.size.y > 1

	# Resolve max width for text wrapping.
	var max_width := 200
	if has_rect:
		max_width = int(bound_rect.size.x)
	elif get_parent() is Control:
		var parent_size = get_parent().size
		if parent_size.x > 10:
			max_width = int(parent_size.x)

	# Measure natural text width to decide whether wrapping is needed.
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var natural_width = font.get_string_size(dialogue_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	if has_rect:
		autowrap_mode = TextServer.AUTOWRAP_WORD
		custom_minimum_size = bound_rect.size
		size = bound_rect.size
	elif natural_width > max_width:
		autowrap_mode = TextServer.AUTOWRAP_WORD
		custom_minimum_size = Vector2(max_width, 0)
	else:
		autowrap_mode = TextServer.AUTOWRAP_OFF
		custom_minimum_size = Vector2.ZERO

	# Wait for layout to recalculate size.
	await get_tree().process_frame

	# Place bubble in the exact backend-designed percent rect.
	if has_rect:
		set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		position = bound_rect.position
		size = bound_rect.size
	
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
