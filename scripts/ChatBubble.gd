extends Panel
class_name ChatBubble

@export var dialogue_label: Label
@export var timer: Timer

func _ready():
	if not dialogue_label:
		dialogue_label = $DialogueLabel
	if not timer:
		timer = $Timer
	
	if timer:
		timer.timeout.connect(_on_timer_timeout)

func show_dialogue(text: String, duration: float = 3.0):
	if dialogue_label:
		dialogue_label.text = text
	
	# Adjust bubble size based on text length (rough estimation)
	var text_length = text.length()
	var estimated_width = min(max(text_length * 8, 120), 300)  # 8 pixels per character
	var estimated_height = max(40, (text_length / 25.0) * 20 + 40)  # Estimate height based on wrapping
	
	# Set bubble size
	custom_minimum_size = Vector2(estimated_width, estimated_height)
	size = Vector2(estimated_width, estimated_height)
	
	# Don't adjust position here - we'll set the correct position from NPC script
	
	visible = true
	
	if timer:
		timer.wait_time = duration
		timer.start()

func _on_timer_timeout():
	hide_bubble()

func hide_bubble():
	visible = false
	queue_free()
