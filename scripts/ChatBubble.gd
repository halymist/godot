extends Label
class_name ChatBubble

var timer_id: int = 0

func _ready():
	visible = false

func show_with_text(bubble_text: String, duration: float = 4.0):
	show_dialogue(bubble_text, duration)

func show_dialogue(dialogue_text: String, duration: float = 4.0, skip_animation: bool = false):
	text = dialogue_text
	
	# Get parent container size as boundary
	var max_width = 200  # Default fallback
	if get_parent() is Control:
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
