extends NinePatchRect
class_name ChatBubble

@export var dialogue_label: Label
@export var max_width: float = 170.0
@export var padding: Vector2 = Vector2(12, 10)

func _ready():
	if not dialogue_label:
		dialogue_label = get_node_or_null("DialogueLabel")
	visible = false

func show_dialogue(text: String, duration: float = 4.0):
	if not dialogue_label:
		return
	
	dialogue_label.text = text
	dialogue_label.custom_minimum_size = Vector2(0, 0)
	
	# Wait for label to calculate its size with autowrap
	await get_tree().process_frame
	
	# Calculate wrapped text size
	var label_min_size = dialogue_label.get_minimum_size()
	
	# Clamp width to max_width
	var actual_width = min(label_min_size.x, max_width - (padding.x * 2))
	dialogue_label.custom_minimum_size.x = actual_width
	
	# Wait another frame for size recalculation with the constrained width
	await get_tree().process_frame
	
	# Now get the final size
	var final_label_size = dialogue_label.size
	
	# Set bubble size to fit label + padding
	var bubble_size = Vector2(
		final_label_size.x + (padding.x * 2),
		final_label_size.y + (padding.y * 2)
	)
	
	size = bubble_size
	custom_minimum_size = bubble_size
	
	visible = true
	
	# Auto-hide after duration
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		visible = false

func hide_bubble():
	visible = false
