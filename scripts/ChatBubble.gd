extends Label
class_name ChatBubble

var timer_id: int = 0
var _has_custom_bounds: bool = false
var _bounds_corner_a: Vector2 = Vector2.ZERO
var _bounds_corner_b: Vector2 = Vector2.ZERO

func _ready():
	z_index = 20
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)

func set_message_bounds(corner_a: Vector2, corner_b: Vector2):
	_has_custom_bounds = true
	_bounds_corner_a = corner_a
	_bounds_corner_b = corner_b

func clear_message_bounds():
	_has_custom_bounds = false

func show_with_text(bubble_text: String, duration: float = 4.0):
	show_dialogue(bubble_text, duration)

func _bounds_rect() -> Rect2:
	var parent_control = get_parent() as Control
	if not parent_control:
		return Rect2()

	var bounds_control: Control = parent_control
	var image_area = parent_control.get_node_or_null("ImageArea") as Control
	if image_area:
		bounds_control = image_area

	if bounds_control.size.x <= 0.0 or bounds_control.size.y <= 0.0:
		return Rect2()

	var left = min(_bounds_corner_a.x, _bounds_corner_b.x) * 0.01 * bounds_control.size.x
	var top = min(_bounds_corner_a.y, _bounds_corner_b.y) * 0.01 * bounds_control.size.y
	var width = abs(_bounds_corner_b.x - _bounds_corner_a.x) * 0.01 * bounds_control.size.x
	var height = abs(_bounds_corner_b.y - _bounds_corner_a.y) * 0.01 * bounds_control.size.y
	var local_position = Vector2(left, top)
	if bounds_control != parent_control:
		local_position += bounds_control.position

	return Rect2(local_position, Vector2(width, height))

func _fallback_rect() -> Rect2:
	var parent_control = get_parent() as Control
	if parent_control and parent_control.size.x > 0.0 and parent_control.size.y > 0.0:
		return Rect2(Vector2.ZERO, parent_control.size)
	return Rect2(Vector2.ZERO, Vector2(200.0, 120.0))

func _fit_text_size(text_value: String, max_size: Vector2) -> Vector2:
	var font = get_theme_default_font()
	var font_size = get_theme_default_font_size()
	var natural_width = font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var target_width = clamp(natural_width, 1.0, max_size.x)
	autowrap_mode = TextServer.AUTOWRAP_WORD
	custom_minimum_size = Vector2(target_width, 0.0)
	size = Vector2(target_width, max_size.y)
	return Vector2(target_width, min(max_size.y, max(1.0, get_combined_minimum_size().y)))

func show_dialogue(dialogue_text: String, duration: float = 4.0, skip_animation: bool = false):
	text = dialogue_text
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)

	var bounds = _bounds_rect() if _has_custom_bounds else Rect2()
	if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		bounds = _fallback_rect()

	var fitted_size = _fit_text_size(dialogue_text, bounds.size)
	await get_tree().process_frame
	fitted_size = _fit_text_size(dialogue_text, bounds.size)

	position = bounds.position
	size = fitted_size

	if not skip_animation:
		visible = true
		scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(self, "scale", Vector2.ONE, 0.3)

	timer_id += 1
	var current_timer_id = timer_id
	if duration > 0:
		await get_tree().create_timer(duration).timeout
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
