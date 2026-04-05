extends Button

@export var chat_panel: Panel
@export var chat_container: VBoxContainer
@export var scroll_container: ScrollContainer
@export var global_button: Button
@export var local_button: Button
@export var chat_input: LineEdit
@export var send_button: Button

var last_message_time: String = ""
var current_filter: String = "local"  # "global", "local", or "all"

func _ready():
	# Connect toggle buttons with null checks
	global_button.toggled.connect(_on_global_button_toggled)
	local_button.toggled.connect(_on_local_button_toggled)
	send_button.pressed.connect(_on_send_button_pressed)
	chat_input.text_submitted.connect(_on_chat_input_submitted)
	chat_input.focus_exited.connect(_on_chat_input_focus_exited)
	
	visibility_changed.connect(_on_visibility_changed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_update_button_visuals()
	display_chat_messages()

func _input(event: InputEvent):
	# Release chat input focus when clicking anywhere outside it
	if event is InputEventMouseButton and event.pressed and chat_input.has_focus():
		var input_rect = chat_input.get_global_rect()
		if not input_rect.has_point(event.position):
			chat_input.release_focus()

func _on_visibility_changed():
	# Scroll to bottom whenever chat becomes visible
	if visible:
		_scroll_to_bottom()

func display_chat_messages():
	if not chat_container:
		print("ERROR: chat_container not assigned!")
		return
	
	# Clear existing messages and reset time tracking
	for child in chat_container.get_children():
		child.queue_free()
	last_message_time = ""  # Reset so first message doesn't trigger separator
	
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

func _on_global_button_toggled(toggled_on: bool):
	if toggled_on:
		current_filter = "global"
		display_chat_messages()

func _on_local_button_toggled(toggled_on: bool):
	if toggled_on:
		current_filter = "local"
		display_chat_messages()

func _on_chat_input_submitted(_text: String):
	_on_send_button_pressed()
	chat_input.release_focus()

func _on_chat_input_focus_exited():
	# Ensure virtual keyboard closes on mobile / web
	pass

func _on_send_button_pressed():
	var message_text = chat_input.text.strip_edges()
	if message_text.is_empty():
		return
	
	# 0 = local, 1 = global
	var chat_type = 1 if current_filter == "global" else 0
	Websocket.send_chat(chat_type, message_text)
	chat_input.text = ""
	chat_input.release_focus()

func _update_button_visuals():
	"""Update button toggle state based on current filter"""
	local_button.button_pressed = current_filter == "local"
	global_button.button_pressed = current_filter == "global"

func add_chat_message(chat_message: GameInfo.ChatMessage):
	# Add timestamp separator if more than 10 minutes passed since last message
	# or if this is the first message and it's older than 10 minutes from now
	var message_time = Time.get_unix_time_from_datetime_string(chat_message.timestamp.replace("Z", "+00:00"))
	var should_show_separator = false
	
	if last_message_time == "":
		# First message - check if older than 10 minutes from current time
		var current_unix = Time.get_unix_time_from_system()
		if current_unix - message_time >= 600:
			should_show_separator = true
	else:
		# Not first message - check time difference from previous message
		var last_time = Time.get_unix_time_from_datetime_string(last_message_time.replace("Z", "+00:00"))
		if message_time - last_time >= 600:
			should_show_separator = true
	
	if should_show_separator:
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
