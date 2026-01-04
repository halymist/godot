extends NinePatchRect
class_name ChatBubble

@export var dialogue_label: Label
@export var max_width: float = 170.0
@export var padding: Vector2 = Vector2(12, 14)  # Extra vertical padding to prevent overflow

func _ready():
	if not dialogue_label:
		dialogue_label = get_node_or_null("DialogueLabel")
	visible = false

func show_with_text(text: String, duration: float = 4.0):
	if not dialogue_label:
		return
	
	# Set the text
	dialogue_label.text = text
	
	# Calculate and resize
	_resize_to_fit()
	
	# Pop-up animation
	scale = Vector2(0.5, 0.5)
	visible = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	
	# Auto-hide after duration
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		visible = false

func _resize_to_fit():
	if not dialogue_label:
		return
	
	var text = dialogue_label.text
	var font = dialogue_label.get_theme_default_font()
	var font_size = dialogue_label.get_theme_default_font_size()
	
	# Calculate text width without wrapping
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# If natural width fits within max_width, use it
	if text_size.x <= (max_width - padding.x * 2):
		dialogue_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		dialogue_label.custom_minimum_size = Vector2.ZERO
		
		var bubble_width = text_size.x + (padding.x * 2)
		var bubble_height = text_size.y + (padding.y * 2)
		size = Vector2(bubble_width, bubble_height)
		custom_minimum_size = Vector2(bubble_width, bubble_height)
	else:
		# Text is too long, enable wrapping at max_width
		dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var wrap_width = max_width - (padding.x * 2)
		dialogue_label.custom_minimum_size.x = wrap_width
		
		# Calculate wrapped text height
		var wrapped_size = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, font_size)
		
		size = Vector2(max_width, wrapped_size.y + padding.y * 2)
		custom_minimum_size = Vector2(max_width, wrapped_size.y + padding.y * 2)

func show_dialogue(text: String, duration: float = 4.0):
	# Kept for compatibility
	show_with_text(text, duration)

func hide_bubble():
	visible = false
