extends Label
class_name ChatBubble

var timer_id: int = 0
var _has_custom_bounds: bool = false
# Two opposite corners of the msg_rect in source texture pixel space
# (server sends bottom-left + top-right).
var _bounds_corner_a: Vector2 = Vector2.ZERO
var _bounds_corner_b: Vector2 = Vector2.ZERO

func _ready():
	visible = false

func set_message_bounds(corner_a: Vector2, corner_b: Vector2):
	_has_custom_bounds = true
	_bounds_corner_a = corner_a
	_bounds_corner_b = corner_b

func clear_message_bounds():
	_has_custom_bounds = false

func show_with_text(bubble_text: String, duration: float = 4.0):
	show_dialogue(bubble_text, duration)

# Convert a Rect2 from source-texture pixel coords to parent (panel) local
# coords, accounting for the parent TextureRect's stretch mode. Returns the
# input rect unchanged when no conversion is possible.
func _texture_rect_to_panel_local(rect_in_tex: Rect2) -> Rect2:
	var parent = get_parent()
	if not (parent is TextureRect) or parent.texture == null:
		return rect_in_tex

	var tex_size: Vector2 = parent.texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return rect_in_tex

	var panel_size: Vector2 = parent.size
	if panel_size.x <= 0 or panel_size.y <= 0:
		return rect_in_tex

	var sx := panel_size.x / tex_size.x
	var sy := panel_size.y / tex_size.y
	var scale_factor := 1.0
	var offset := Vector2.ZERO

	# StretchMode values used in the panels (see Scenes/game.tscn): stretch_mode = 6
	# corresponds to STRETCH_KEEP_ASPECT_COVERED. Treat anything covered/centered
	# uniformly; for KEEP we'd use 1.0 but that's not used here.
	match int(parent.stretch_mode):
		6: # KEEP_ASPECT_COVERED
			scale_factor = max(sx, sy)
		5: # KEEP_ASPECT_CENTERED
			scale_factor = min(sx, sy)
		4: # KEEP_ASPECT
			scale_factor = min(sx, sy)
		_:
			# STRETCH (default) and others: independent x/y scaling
			return Rect2(
				rect_in_tex.position * Vector2(sx, sy),
				rect_in_tex.size * Vector2(sx, sy)
			)

	var displayed := tex_size * scale_factor
	offset = (panel_size - displayed) * 0.5
	return Rect2(rect_in_tex.position * scale_factor + offset, rect_in_tex.size * scale_factor)

func show_dialogue(dialogue_text: String, duration: float = 4.0, skip_animation: bool = false):
	text = dialogue_text

	# Compute the panel-local rect we are allowed to draw inside.
	var bound_rect: Rect2 = Rect2()
	var has_rect := false
	if _has_custom_bounds:
		var min_pt := Vector2(min(_bounds_corner_a.x, _bounds_corner_b.x), min(_bounds_corner_a.y, _bounds_corner_b.y))
		var max_pt := Vector2(max(_bounds_corner_a.x, _bounds_corner_b.x), max(_bounds_corner_a.y, _bounds_corner_b.y))
		var tex_rect := Rect2(min_pt, max_pt - min_pt)
		bound_rect = _texture_rect_to_panel_local(tex_rect)
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
		# Always clamp to the rect width so the bubble never grows past it.
		autowrap_mode = TextServer.AUTOWRAP_WORD
		custom_minimum_size = Vector2(max_width, 0)
		size = Vector2(max_width, size.y)
	elif natural_width > max_width:
		autowrap_mode = TextServer.AUTOWRAP_WORD
		custom_minimum_size.x = max_width
	else:
		autowrap_mode = TextServer.AUTOWRAP_OFF
		custom_minimum_size.x = 0

	# Wait for layout to recalculate size.
	await get_tree().process_frame

	# Place bubble bottom-aligned within the rect (in panel-local coords).
	if has_rect:
		var bubble_h: float = min(size.y, bound_rect.size.y)
		set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		position = Vector2(bound_rect.position.x, bound_rect.position.y + bound_rect.size.y - bubble_h)
	
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
