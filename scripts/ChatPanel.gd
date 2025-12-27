extends Button

@export var chat_panel: Panel
@export var chat_container: VBoxContainer
@export var scroll_container: ScrollContainer
@export var global_button: Button
@export var local_button: Button

var saved_scroll_position: int = 0
var last_message_time: String = ""
var current_filter: String = "global"  # "global", "local", or "all"

func _ready():
	# Connect toggle buttons
	global_button.pressed.connect(_on_global_button_pressed)
	local_button.pressed.connect(_on_local_button_pressed)
	
	# Set initial button states
	_update_button_states()
	display_chat_messages()

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
