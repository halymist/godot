extends Panel

@export var chat_panel: Panel
@export var chat_container: VBoxContainer
@export var scroll_container: ScrollContainer
@export var global_button: Button
@export var local_button: Button

var is_chat_open = false
var saved_scroll_position: int = 0
var last_message_time: String = ""
var current_filter: String = "global"  # "global", "local", or "all"

# Drag-to-scroll variables
var is_dragging = false
var drag_start_position: Vector2
var scroll_start_position: float

func _ready():
	# Connect toggle buttons
	if global_button:
		global_button.pressed.connect(_on_global_button_pressed)
	if local_button:
		local_button.pressed.connect(_on_local_button_pressed)
	
	# Set initial button states
	_update_button_states()
	
	# Load chat messages when the panel is ready
	display_chat_messages()
	
	# Connect click on overlay to close chat
	gui_input.connect(_on_overlay_input)
	
	# Set up drag-to-scroll for the scroll container and chat container
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_container_input)
	if chat_container:
		chat_container.gui_input.connect(_on_scroll_container_input)
	
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

func _on_scroll_container_input(event: InputEvent):
	if not scroll_container:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				is_dragging = true
				drag_start_position = event.position
				scroll_start_position = scroll_container.scroll_vertical
			else:
				# Stop dragging
				is_dragging = false
	
	elif event is InputEventMouseMotion and is_dragging:
		# Calculate scroll delta based on mouse movement
		var delta = drag_start_position.y - event.position.y
		var new_scroll = scroll_start_position + delta
		
		# Clamp to valid scroll range
		var max_scroll = scroll_container.get_v_scroll_bar().max_value
		new_scroll = clamp(new_scroll, 0, max_scroll)
		
		# Apply the scroll
		scroll_container.scroll_vertical = int(new_scroll)
		
		# Update saved position
		saved_scroll_position = scroll_container.scroll_vertical

func show_chat():
	if is_chat_open or not chat_panel:
		return
		
	is_chat_open = true
	visible = true
	chat_panel.position.x = 0
	
	# Restore scroll position
	_restore_scroll_position()

func hide_chat():
	if not is_chat_open or not chat_panel:
		return
	
	# Save current scroll position before hiding
	_save_scroll_position()
		
	is_chat_open = false
	
	# Clear from GameInfo if it's the current overlay
	if GameInfo.get_current_panel_overlay() == self:
		GameInfo.set_current_panel_overlay(null)
	
	visible = false

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
	
	# Add each chat message that matches the current filter
	for message in GameInfo.chat_messages:
		if _should_show_message(message):
			add_chat_message(message)
	
	# Only scroll to bottom on first load (when saved_scroll_position is 0)
	if saved_scroll_position == 0:
		call_deferred("_scroll_to_bottom")

func _should_show_message(chat_message: GameInfo.ChatMessage) -> bool:
	# Show message based on current filter
	match current_filter:
		"global":
			return chat_message.type == "global"
		"local":
			return chat_message.type == "local"
		"all":
			return true
		_:
			return true  # Default to showing all messages

func _on_global_button_pressed():
	current_filter = "global"
	_update_button_states()
	display_chat_messages()

func _on_local_button_pressed():
	current_filter = "local"
	_update_button_states()
	display_chat_messages()

func _update_button_states():
	if not global_button or not local_button:
		return
	
	# Update button colors based on active filter
	match current_filter:
		"global":
			# Global button active - gold colors
			global_button.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4, 1))
			global_button.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.6, 1))
			global_button.add_theme_color_override("font_pressed_color", Color(0.8, 0.6, 0.3, 1))
			
			# Local button inactive - gray colors  
			local_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			local_button.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7, 1))
			local_button.add_theme_color_override("font_pressed_color", Color(0.4, 0.4, 0.4, 1))
		"local":
			# Local button active - gold colors
			local_button.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4, 1))
			local_button.add_theme_color_override("font_hover_color", Color(1, 0.85, 0.6, 1))
			local_button.add_theme_color_override("font_pressed_color", Color(0.8, 0.6, 0.3, 1))
			
			# Global button inactive - gray colors
			global_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
			global_button.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7, 1))
			global_button.add_theme_color_override("font_pressed_color", Color(0.4, 0.4, 0.4, 1))

func add_chat_message(chat_message: GameInfo.ChatMessage):
	# Check if we need to add a timestamp separator
	_add_timestamp_separator_if_needed(chat_message)
	
	# Create simple label for each message
	var message_label = RichTextLabel.new()
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.bbcode_enabled = true
	
	# Set smaller font size
	message_label.add_theme_font_size_override("normal_font_size", 12)
	message_label.add_theme_font_size_override("bold_font_size", 12)
	
	# Format with bold sender name and colored text
	var sender_color = "white"
	if chat_message.status == "lord":
		sender_color = "gold"
	
	# Create rich text with bold sender name
	var rich_text = "[color=" + sender_color + "][b]" + chat_message.sender + "[/b][/color]: " + chat_message.message
	message_label.text = rich_text
	
	# Add to container
	chat_container.add_child(message_label)

func _scroll_to_bottom():
	if scroll_container:
		# Wait a frame for the content to be properly sized
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
		# Update saved position to bottom
		saved_scroll_position = scroll_container.scroll_vertical

func _add_timestamp_separator_if_needed(chat_message: GameInfo.ChatMessage):
	if last_message_time == "":
		last_message_time = chat_message.timestamp
		return
	
	# Parse timestamps to compare time difference
	var last_time = Time.get_unix_time_from_datetime_string(last_message_time.replace("Z", "+00:00"))
	var current_time = Time.get_unix_time_from_datetime_string(chat_message.timestamp.replace("Z", "+00:00"))
	
	# If more than 10 minutes (600 seconds) difference, add timestamp separator
	if current_time - last_time >= 600:
		_add_timestamp_separator(chat_message.timestamp)
	
	last_message_time = chat_message.timestamp

func _add_timestamp_separator(timestamp: String):
	# Create a full-width timestamp separator
	var timestamp_label = RichTextLabel.new()
	timestamp_label.fit_content = true
	timestamp_label.scroll_active = false
	timestamp_label.bbcode_enabled = true
	timestamp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Format the timestamp to be more readable and prominent
	var formatted_time = _format_timestamp(timestamp)
	timestamp_label.text = "[center][color=gold][b]" + formatted_time + "[/b][/color][/center]"
	
	# Set larger font size for prominence
	timestamp_label.add_theme_font_size_override("normal_font_size", 14)
	timestamp_label.add_theme_font_size_override("bold_font_size", 14)
	
	# Add directly to chat container to take full width
	chat_container.add_child(timestamp_label)
	
	# Add some spacing
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	chat_container.add_child(spacer)

func _format_timestamp(iso_timestamp: String) -> String:
	# Convert "2025-08-08T10:35:00Z" to "10:35"
	var parts = iso_timestamp.split("T")
	if parts.size() >= 2:
		var time_part = parts[1].split(":")
		if time_part.size() >= 2:
			return time_part[0] + ":" + time_part[1]
	return iso_timestamp  # Fallback to original if parsing fails
