extends Button

@export var chat_panel: Panel
@export var chat_container: VBoxContainer
@export var scroll_container: ScrollContainer
@export var global_button: Button
@export var local_button: Button

var last_message_time: String = ""
var current_filter: String = "global"  # "global", "local", or "all"

func _ready():
	# Connect toggle buttons
	global_button.pressed.connect(_on_global_button_pressed)
	local_button.pressed.connect(_on_local_button_pressed)
	
	display_chat_messages()

func _on_visibility_changed():
	# Scroll to bottom whenever chat becomes visible
	if visible:
		_scroll_to_bottom()

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
	
	# Always scroll to newest messages
	_scroll_to_bottom()

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
	display_chat_messages()

func _on_local_button_pressed():
	current_filter = "local"
	display_chat_messages()

func add_chat_message(chat_message: GameInfo.ChatMessage):
	# Add timestamp separator if more than 10 minutes passed
	if last_message_time != "":
		var last_time = Time.get_unix_time_from_datetime_string(last_message_time.replace("Z", "+00:00"))
		var current_time = Time.get_unix_time_from_datetime_string(chat_message.timestamp.replace("Z", "+00:00"))
		
		if current_time - last_time >= 600:
			# Create timestamp separator
			var timestamp_label = RichTextLabel.new()
			timestamp_label.fit_content = true
			timestamp_label.scroll_active = false
			timestamp_label.bbcode_enabled = true
			timestamp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			timestamp_label.add_theme_font_size_override("normal_font_size", 14)
			timestamp_label.add_theme_font_size_override("bold_font_size", 14)
			
			# Format "2025-08-08T10:35:00Z" to "10:35"
			var parts = chat_message.timestamp.split("T")
			var time_display = chat_message.timestamp
			if parts.size() >= 2:
				var time_part = parts[1].split(":")
				if time_part.size() >= 2:
					time_display = time_part[0] + ":" + time_part[1]
			
			timestamp_label.text = "[center][color=gold][b]" + time_display + "[/b][/color][/center]"
			chat_container.add_child(timestamp_label)
			
			# Add spacing
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 8
			chat_container.add_child(spacer)
	
	last_message_time = chat_message.timestamp
	
	# Create message label
	var message_label = RichTextLabel.new()
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.bbcode_enabled = true
	message_label.mouse_filter = Control.MOUSE_FILTER_PASS  # Let mouse events pass through to ScrollContainer
	message_label.add_theme_font_size_override("normal_font_size", 12)
	message_label.add_theme_font_size_override("bold_font_size", 12)
	
	# Format with bold sender name and colored text
	var sender_color = "white"
	if chat_message.status == "lord":
		sender_color = "gold"
	
	var rich_text = "[color=" + sender_color + "][b]" + chat_message.sender + "[/b][/color]: " + chat_message.message
	message_label.text = rich_text
	
	chat_container.add_child(message_label)

func _scroll_to_bottom():
	# Need to wait for ScrollContainer to recalculate content size
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
