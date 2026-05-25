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
var _should_scroll_to_bottom_on_refresh: bool = false
var _has_opened_chat_once: bool = false
var _mute_dialog_overlay: Control = null
var _mute_dialog_panel: Panel = null
var _mute_dialog_label: Label = null
var _mute_dialog_ok_button: Button = null
var _last_mute_dialog_until: int = 0
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
	if not GameInfo.chat_mute_updated.is_connected(_on_chat_mute_updated):
		GameInfo.chat_mute_updated.connect(_on_chat_mute_updated)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)
	set_process(GameInfo.is_chat_muted())
	_ensure_mute_dialog()
	_update_chat_mute_state()

func _setup():
	_update_toggle_label()
	_should_scroll_to_bottom_on_refresh = true
	display_chat_messages()
	_update_chat_mute_state()

func _input(event: InputEvent):
	# Release chat input focus when clicking anywhere outside it
	if event is InputEventMouseButton and event.pressed and chat_input.has_focus():
		var input_rect = chat_input.get_global_rect()
		if not input_rect.has_point(event.position):
			chat_input.release_focus()

func _gui_input(event: InputEvent):
	if not _is_mute_dialog_visible():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _mute_dialog_panel and not _mute_dialog_panel.get_global_rect().has_point(event.position):
			hide_mute_dialog()
			accept_event()

func _on_visibility_changed():
	if visible and not _has_opened_chat_once:
		_has_opened_chat_once = true
		_should_scroll_to_bottom_on_refresh = true
		display_chat_messages()

func display_chat_messages():
	if not chat_container:
		return

	var preserved_scroll := 0
	if scroll_container:
		preserved_scroll = scroll_container.scroll_vertical
	
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
	
	if _should_scroll_to_bottom_on_refresh:
		_should_scroll_to_bottom_on_refresh = false
		_scroll_to_bottom()
	else:
		_restore_scroll_position(preserved_scroll)

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

func _process(_delta: float):
	if not GameInfo.is_chat_muted():
		set_process(false)
	_update_chat_mute_state()

func _on_send_button_pressed():
	if GameInfo.is_chat_muted():
		show_mute_dialog()
		return
	var message_text = chat_input.text.strip_edges()
	if message_text.is_empty():
		return
	
	# 0 = local, 1 = global
	var chat_type = 1 if current_filter == "global" else 0
	_should_scroll_to_bottom_on_refresh = true
	Websocket.send_chat(chat_type, message_text)
	chat_input.text = ""
	chat_input.release_focus()

func handle_chat_rejection(rejection: Dictionary):
	if int(rejection.get("muted_until", 0)) > 0:
		_last_mute_dialog_until = int(rejection.get("muted_until", 0))
		_update_chat_mute_state()
		show_mute_dialog()

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
		
		# Create first line as "Name: message"
		var sender_color = "#E6B366"  # Golden like settings subheaders
		if chat_message.status == "lord":
			sender_color = "#FFD700"  # Brighter gold for lords
		
		var first_line_label = RichTextLabel.new()
		first_line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		first_line_label.fit_content = true
		first_line_label.scroll_active = false
		first_line_label.bbcode_enabled = true
		first_line_label.mouse_filter = Control.MOUSE_FILTER_PASS
		first_line_label.add_theme_font_size_override("normal_font_size", 12)
		first_line_label.add_theme_font_size_override("bold_font_size", 12)
		first_line_label.text = "[color=%s][b]%s:[/b][/color] %s" % [sender_color, _escape_bbcode(chat_message.sender), _escape_bbcode(chat_message.message)]
		chat_container.add_child(first_line_label)
		last_message_sender = chat_message.sender
		return

	# Follow-up lines from the same sender stay below without repeating the name.
	var message_label = RichTextLabel.new()
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.fit_content = true
	message_label.scroll_active = false
	message_label.bbcode_enabled = true
	message_label.mouse_filter = Control.MOUSE_FILTER_PASS
	message_label.add_theme_font_size_override("normal_font_size", 12)
	message_label.add_theme_font_size_override("bold_font_size", 12)
	message_label.text = _escape_bbcode(chat_message.message)
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

func _restore_scroll_position(previous_scroll: int):
	await get_tree().process_frame
	if not scroll_container:
		return
	var v_scroll_bar = scroll_container.get_v_scroll_bar()
	if not v_scroll_bar:
		return
	scroll_container.scroll_vertical = clampi(previous_scroll, 0, int(v_scroll_bar.max_value))

func _scroll_to_bottom():
	await get_tree().process_frame
	await get_tree().process_frame
	if not scroll_container:
		return
	var v_scroll_bar = scroll_container.get_v_scroll_bar()
	if not v_scroll_bar:
		return
	scroll_container.scroll_vertical = int(v_scroll_bar.max_value)

func _escape_bbcode(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")

func _on_chat_mute_updated():
	_update_chat_mute_state()
	set_process(GameInfo.is_chat_muted())

func _update_chat_mute_state():
	if not chat_input or not send_button:
		return
	var is_muted = GameInfo.is_chat_muted()
	chat_input.editable = not is_muted
	chat_input.focus_mode = Control.FOCUS_NONE if is_muted else Control.FOCUS_ALL
	send_button.disabled = is_muted
	send_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_muted else Control.MOUSE_FILTER_STOP
	send_button.modulate = Color(0.55, 0.55, 0.55, 1.0) if is_muted else Color(1, 1, 1, 1)
	if is_muted:
		chat_input.text = ""
		chat_input.release_focus()
		chat_input.placeholder_text = "Muted for %s" % _format_mute_countdown(GameInfo.get_chat_mute_remaining_seconds())
		if _is_mute_dialog_visible():
			_update_mute_dialog_text()
	else:
		chat_input.placeholder_text = "Type your message..."
		if _is_mute_dialog_visible() and GameInfo.get_chat_mute_remaining_seconds() <= 0:
			hide_mute_dialog()

func _ensure_mute_dialog():
	if _mute_dialog_overlay:
		return
	_mute_dialog_overlay = Control.new()
	_mute_dialog_overlay.visible = false
	_mute_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mute_dialog_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_mute_dialog_overlay)

	_mute_dialog_panel = Panel.new()
	_mute_dialog_panel.custom_minimum_size = Vector2(280, 0)
	_mute_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_mute_dialog_panel.anchor_left = 0.5
	_mute_dialog_panel.anchor_top = 0.5
	_mute_dialog_panel.anchor_right = 0.5
	_mute_dialog_panel.anchor_bottom = 0.5
	_mute_dialog_panel.offset_left = -140.0
	_mute_dialog_panel.offset_top = -70.0
	_mute_dialog_panel.offset_right = 140.0
	_mute_dialog_panel.offset_bottom = 70.0
	_mute_dialog_overlay.add_child(_mute_dialog_panel)

	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.08, 0.07, 0.06, 0.96)
	dialog_style.border_color = Color(0.83, 0.67, 0.30, 1.0)
	dialog_style.border_width_left = 2
	dialog_style.border_width_top = 2
	dialog_style.border_width_right = 2
	dialog_style.border_width_bottom = 2
	dialog_style.corner_radius_top_left = 6
	dialog_style.corner_radius_top_right = 6
	dialog_style.corner_radius_bottom_left = 6
	dialog_style.corner_radius_bottom_right = 6
	dialog_style.content_margin_left = 16
	dialog_style.content_margin_top = 16
	dialog_style.content_margin_right = 16
	dialog_style.content_margin_bottom = 16
	_mute_dialog_panel.add_theme_stylebox_override("panel", dialog_style)

	var dialog_layout = VBoxContainer.new()
	dialog_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_layout.add_theme_constant_override("separation", 12)
	_mute_dialog_panel.add_child(dialog_layout)

	_mute_dialog_label = Label.new()
	_mute_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mute_dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mute_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mute_dialog_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mute_dialog_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mute_dialog_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82, 1.0))
	dialog_layout.add_child(_mute_dialog_label)

	_mute_dialog_ok_button = Button.new()
	_mute_dialog_ok_button.text = "OK"
	_mute_dialog_ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mute_dialog_ok_button.pressed.connect(hide_mute_dialog)
	dialog_layout.add_child(_mute_dialog_ok_button)

func show_mute_dialog():
	_ensure_mute_dialog()
	_update_mute_dialog_text()
	visible = true
	if UIManager.instance:
		UIManager.instance.chat_overlay_active = true
		z_index = 500
	_mute_dialog_overlay.visible = true
	_mute_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_mute_dialog_panel.grab_focus()

func hide_mute_dialog():
	if not _mute_dialog_overlay:
		return
	_mute_dialog_overlay.visible = false
	_mute_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _is_mute_dialog_visible() -> bool:
	return _mute_dialog_overlay != null and _mute_dialog_overlay.visible

func _update_mute_dialog_text():
	if not _mute_dialog_label:
		return
	var remaining = GameInfo.get_chat_mute_remaining_seconds()
	if remaining <= 0 and _last_mute_dialog_until > 0:
		remaining = max(0, _last_mute_dialog_until - int(Time.get_unix_time_from_system()))
	_mute_dialog_label.text = "You are muted for %s" % _format_mute_countdown(remaining)

func _format_mute_countdown(total_seconds: int) -> String:
	var seconds = max(0, total_seconds)
	var minutes = seconds / 60
	var remainder = seconds % 60
	if minutes > 0:
		return "%dm %02ds" % [minutes, remainder]
	return "%ds" % seconds
