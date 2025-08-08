extends Panel

@export var chat_panel: Panel
@export var chat_container: VBoxContainer
@export var scroll_container: ScrollContainer

var is_chat_open = false
var slide_tween: Tween
var saved_scroll_position: int = 0

func _ready():
	# Load chat messages when the panel is ready
	display_chat_messages()
	
	# Connect click on overlay to close chat
	gui_input.connect(_on_overlay_input)
	
	# Ensure chat starts hidden off-screen
	if chat_panel:
		var chat_width = get_viewport().get_visible_rect().size.x * 0.7
		chat_panel.position.x = -chat_width

func _on_overlay_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click was outside the chat panel
			var click_pos = event.position
			var chat_rect = Rect2(chat_panel.position, chat_panel.size)
			
			if not chat_rect.has_point(click_pos):
				hide_chat()

func show_chat():
	if is_chat_open or not chat_panel:
		return
		
	is_chat_open = true
	visible = true
	
	# Animate sliding in
	if slide_tween:
		slide_tween.kill()
	slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_OUT)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	var target_x = 0.0
	slide_tween.tween_property(chat_panel, "position:x", target_x, 0.3)
	
	# Restore scroll position after animation
	slide_tween.tween_callback(_restore_scroll_position)

func hide_chat():
	if not is_chat_open or not chat_panel:
		return
	
	# Save current scroll position before hiding
	_save_scroll_position()
		
	is_chat_open = false
	
	# Animate sliding out
	if slide_tween:
		slide_tween.kill()
	slide_tween = create_tween()
	slide_tween.set_ease(Tween.EASE_IN)
	slide_tween.set_trans(Tween.TRANS_CUBIC)
	
	var chat_width = get_viewport().get_visible_rect().size.x * 0.7
	var target_x = -chat_width
	slide_tween.tween_property(chat_panel, "position:x", target_x, 0.3)
	
	# Hide overlay after animation
	slide_tween.tween_callback(func(): visible = false)

func toggle_chat():
	if is_chat_open:
		hide_chat()
	else:
		show_chat()

func _save_scroll_position():
	if scroll_container:
		saved_scroll_position = scroll_container.scroll_vertical

func _restore_scroll_position():
	if scroll_container:
		# Wait a frame for the content to be properly sized
		await get_tree().process_frame
		scroll_container.scroll_vertical = saved_scroll_position

func display_chat_messages():
	if not chat_container:
		print("ERROR: chat_container not assigned!")
		return
	
	# Clear existing messages
	for child in chat_container.get_children():
		child.queue_free()
	
	# Add each chat message
	for message in GameInfo.chat_messages:
		add_chat_message(message)
	
	# Only scroll to bottom on first load (when saved_scroll_position is 0)
	if saved_scroll_position == 0:
		call_deferred("_scroll_to_bottom")

func add_chat_message(chat_message: GameInfo.ChatMessage):
	# Create simple label for each message
	var message_label = Label.new()
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Set smaller font size
	message_label.add_theme_font_size_override("font_size", 12)
	
	# Set text color based on status  
	if chat_message.status == "lord":
		message_label.modulate = Color.GOLD
	else:
		message_label.modulate = Color.WHITE
	
	# Simple format: Sender: message
	message_label.text = chat_message.sender + ": " + chat_message.message
	
	# Add to container
	chat_container.add_child(message_label)

func _scroll_to_bottom():
	if scroll_container:
		# Wait a frame for the content to be properly sized
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
		# Update saved position to bottom
		saved_scroll_position = scroll_container.scroll_vertical
