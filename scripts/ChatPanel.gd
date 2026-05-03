extends Button

@export var chat_panel: Panel
@export var chat_container: VBoxContainer
@export var scroll_container: ScrollContainer
@export var toggle_button: Button
@export var chat_input: LineEdit
@export var send_button: TextureButton

var last_message_time: String = ""
var last_message_sender: String = ""
var current_filter: String = "local"  # "global" or "local"
const TIME_SEPARATOR_GAP_SECONDS := 30 * 60

func _ready():
	toggle_button.pressed.connect(_on_toggle_pressed)
	send_button.pressed.connect(_on_send_button_pressed)
	chat_input.text_submitted.connect(_on_chat_input_submitted)
	chat_input.focus_exited.connect(_on_chat_input_focus_exited)
	
	# Send button hover/click feedback
	var golden = Color(0.9, 0.7, 0.4, 1)
	send_button.mouse_entered.connect(func(): send_button.modulate = golden)
	send_button.mouse_exited.connect(func(): send_button.modulate = Color(1, 1, 1, 1))
	send_button.button_down.connect(func(): send_button.modulate = golden)
	send_button.button_up.connect(func(): send_button.modulate = Color(1, 1, 1, 1))
	
	visibility_changed.connect(_on_visibility_changed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_update_toggle_label()
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
		return
	
	# Clear existing messages and reset tracking
	for child in chat_container.get_children():
		child.queue_free()
	last_message_time = ""
	last_message_sender = ""
	
	# Add each chat message that matches the current filter, ordered by timestamp (oldest -> newest)
	var filtered_messages: Array = []
	for message in GameInfo.chat_messages:
		if _should_show_message(message):
			filtered_messages.append(message)

	filtered_messages.sort_custom(func(a, b):
		return _message_timestamp_to_unix(a.timestamp) < _message_timestamp_to_unix(b.timestamp)
	)

	for message in filtered_messages:
		add_chat_message(message)
	
	# Always scroll to newest messages
	_scroll_to_bottom()

func _should_show_message(chat_message: GameInfo.ChatMessage) -> bool:
	match current_filter:
		"global":
			return chat_message.type == "global"
		"local":
			return chat_message.type == "local"
		_:
			return true

func _on_toggle_pressed():
	"""Toggle between local and global chat"""
	if current_filter == "local":
		current_filter = "global"
	else:
		current_filter = "local"
	_update_toggle_label()
	display_chat_messages()

func _update_toggle_label():
	"""Show the opposite channel name on the toggle button"""
	if current_filter == "local":
		toggle_button.text = "Global"
	else:
		toggle_button.text = "Local"

func _on_chat_input_submitted(_text: String):
	_on_send_button_pressed()
	chat_input.release_focus()

func _on_chat_input_focus_exited():
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

func add_chat_message(chat_message: GameInfo.ChatMessage):
	var message_time = _message_timestamp_to_unix(chat_message.timestamp)
	var should_show_separator = (last_message_time == "")

	if last_message_time != "" and not should_show_separator:
		var last_time = _message_timestamp_to_unix(last_message_time)
		if message_time - last_time >= TIME_SEPARATOR_GAP_SECONDS:
			should_show_separator = true
	
	if should_show_separator:
		last_message_sender = ""  # Reset grouping after time separator
		var time_display = _format_separator_timestamp(message_time)
		
		# Create separator row: ── 20:14 ──
		var sep_row = HBoxContainer.new()
		sep_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sep_row.alignment = BoxContainer.ALIGNMENT_CENTER
		sep_row.add_theme_constant_override("separation", 8)
		
		var left_sep = HSeparator.new()
		left_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sep_row.add_child(left_sep)
		
		var time_label = Label.new()
		time_label.text = time_display
		time_label.add_theme_font_size_override("font_size", 12)
		time_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4, 1))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sep_row.add_child(time_label)
		
		var right_sep = HSeparator.new()
		right_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sep_row.add_child(right_sep)
		
		chat_container.add_child(sep_row)
		
		var spacer = Control.new()
		spacer.custom_minimum_size.y = 4
		chat_container.add_child(spacer)
	
	last_message_time = chat_message.timestamp
	
	# Show sender name only if different from last message sender
	var same_sender = (chat_message.sender == last_message_sender)
	
	if not same_sender:
		# Add small spacing between different sender groups (except first message)
		if last_message_sender != "":
			var group_spacer = Control.new()
			group_spacer.custom_minimum_size.y = 6
			chat_container.add_child(group_spacer)
		
		# Create sender name label
		var sender_color = "#E6B366"  # Golden like settings subheaders
		if chat_message.status == "lord":
			sender_color = "#FFD700"  # Brighter gold for lords
		
		var name_label = RichTextLabel.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.fit_content = true
		name_label.scroll_active = false
		name_label.bbcode_enabled = true
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.add_theme_font_size_override("normal_font_size", 14)
		name_label.add_theme_font_size_override("bold_font_size", 14)
		name_label.text = "[color=" + sender_color + "][b]" + chat_message.sender + "[/b][/color]"
		chat_container.add_child(name_label)
		last_message_sender = chat_message.sender
	
	# Create message content (just the text, no sender name)
	var message_label = RichTextLabel.new()
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.bbcode_enabled = true
	message_label.mouse_filter = Control.MOUSE_FILTER_PASS
	message_label.add_theme_font_size_override("normal_font_size", 12)
	message_label.add_theme_font_size_override("bold_font_size", 12)
	message_label.text = chat_message.message
	chat_container.add_child(message_label)

func _format_separator_timestamp(message_time_unix: int) -> String:
	if message_time_unix <= 0:
		return "Unknown"

	var dt = Time.get_datetime_dict_from_unix_time(message_time_unix)
	if dt.is_empty():
		return "Unknown"

	var hours = int(dt.get("hour", 0))
	var minutes = int(dt.get("minute", 0))
	var time_display = "%02d:%02d" % [hours, minutes]

	var now_unix = int(Time.get_unix_time_from_system())
	if now_unix - message_time_unix >= 86400:
		var day = int(dt.get("day", 0))
		var month = int(dt.get("month", 0))
		time_display += " (%02d.%02d)" % [day, month]

	return time_display

func _message_timestamp_to_unix(timestamp: String) -> int:
	if timestamp.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_string(timestamp.replace("Z", "+00:00")))

func _scroll_to_bottom():
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
