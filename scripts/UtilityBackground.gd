extends Control
class_name UtilityBackground

@export var chat_bubble: ChatBubble

@export var on_entered_greetings: Array[String] = [
	"Welcome to my forge!",
	"Looking to temper your gear?",
	"I can make that weapon even stronger!",
	"Need some metalwork done?"
]

@export var on_action_greetings: Array[String] = [
	"Ah, let me take a look at that...",
	"Nice piece of equipment!",
	"I can definitely work with this.",
	"Good choice bringing this to me!"
]

@export var greeting_duration: float = 4.0
@export var cooldown_between_messages: float = 5.0

var last_message_time: float = -999.0  # Time when last message was shown

func show_entered_greeting():
	if not chat_bubble or on_entered_greetings.is_empty():
		return
	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_message_time < cooldown_between_messages:
		return  # Still in cooldown, skip showing message
	
	var greeting = on_entered_greetings[randi() % on_entered_greetings.size()]
	chat_bubble.show_with_text(greeting, greeting_duration)
	last_message_time = current_time

func show_action_greeting():
	if not chat_bubble or on_action_greetings.is_empty():
		return
	# Check cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_message_time < cooldown_between_messages:
		return  # Still in cooldown, skip showing message
	
	var greeting = on_action_greetings[randi() % on_action_greetings.size()]
	chat_bubble.show_with_text(greeting, greeting_duration)
	last_message_time = current_time
