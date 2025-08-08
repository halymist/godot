extends Panel

@export var chat_container: VBoxContainer
@export var scroll_container: ScrollContainer

func _ready():
	# Load chat messages when the panel is ready
	display_chat_messages()

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
	
	# Scroll to bottom after messages are added
	call_deferred("_scroll_to_bottom")

func add_chat_message(chat_message: GameInfo.ChatMessage):
	# Create a container for this message
	var message_container = HBoxContainer.new()
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Create the message label
	var message_label = RichTextLabel.new()
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	message_label.custom_minimum_size.y = 30
	message_label.bbcode_enabled = true
	message_label.fit_content = true
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Set text color based on status
	var color = ""
	if chat_message.status == "lord":
		color = "[color=gold]"  # Gold color for lords
	else:
		color = "[color=white]"  # White color for peasants
	
	# Format the message: [color]Sender:[/color] message
	var formatted_text = color + chat_message.sender + ":[/color] " + chat_message.message
	message_label.text = formatted_text
	
	# Add to containers
	message_container.add_child(message_label)
	chat_container.add_child(message_container)

func _scroll_to_bottom():
	if scroll_container:
		# Wait a frame for the content to be properly sized
		await get_tree().process_frame
		scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)

# Function to check if we should show timestamp
# This could be expanded later to show timestamps after periods of inactivity
func should_show_timestamp(_current_message: GameInfo.ChatMessage, _previous_message: GameInfo.ChatMessage) -> bool:
	# For now, we don't show timestamps for every message as requested
	# This can be expanded later to show timestamps after long periods
	return false
