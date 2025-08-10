extends TextureRect
class_name NPC

@export var npc_name: String = ""
@export var status: String = "peasant"
@export var npc_data: Dictionary = {}

@onready var click_button: Button = $ClickButton

signal npc_clicked(npc: NPC)
signal npc_hovered(npc: NPC)
signal npc_hover_exited(npc: NPC)

var chat_bubble: Panel = null
var chat_bubble_scene = preload("res://Scenes/ChatBubble.tscn")

func _ready():
	# Connect the button signals
	click_button.button_up.connect(_on_button_pressed)
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)
	
	# Set default NPC texture
	var npc_texture_path = "res://assets/images/fallback/npc.png"
	if ResourceLoader.exists(npc_texture_path):
		texture = load(npc_texture_path)

func _on_button_pressed():
	var quest_id = npc_data.get("questid", null)
	
	if quest_id != null:
		# NPC has a quest - emit signal for quest panel
		npc_clicked.emit(self)
	else:
		# No quest - just show dialogue in chat bubble (already shown on hover)
		pass
	
	print("Clicked NPC: ", npc_name)

func _on_mouse_entered():
	var quest_id = npc_data.get("questid", null)
	
	if quest_id == null:
		# No quest - show dialogue as chat bubble
		show_chat_bubble()
	
	npc_hovered.emit(self)

func _on_mouse_exited():
	hide_chat_bubble()
	npc_hover_exited.emit(self)

func show_chat_bubble():
	if chat_bubble:
		hide_chat_bubble()
	
	var dialogue = npc_data.get("dialogue", "...")
	chat_bubble = chat_bubble_scene.instantiate()
	
	# Add to parent's parent scene (since we're in a ScrollContainer)
	var scene_root = get_tree().current_scene
	scene_root.add_child(chat_bubble)
	
	# Get global position and convert to screen coordinates
	var npc_global_pos = global_position
	var scroll_container = get_parent().get_parent()  # VillageContent -> ScrollContainer
	
	# Adjust for scroll position
	var scroll_offset = Vector2.ZERO
	if scroll_container is ScrollContainer:
		scroll_offset = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
	
	# First show the dialogue to get the correct bubble size
	chat_bubble.show_dialogue(dialogue, 3.0)
	
	# Wait one frame for size to be calculated
	await get_tree().process_frame
	
	# Now position bubble directly above NPC with minimal padding, constrained to game scene
	var bubble_size = chat_bubble.size
	var initial_bubble_pos = Vector2(
		npc_global_pos.x - scroll_offset.x - (bubble_size.x / 2) + (size.x / 2),  # Center bubble over NPC
		npc_global_pos.y - scroll_offset.y - bubble_size.y - 5   # Position directly above NPC with 5px padding
	)
	
	# Get game scene bounds for constraint
	var game_scene = get_tree().current_scene.find_child("GameScene", true, false)
	var bounds_rect = Rect2(Vector2.ZERO, Vector2(1080, 1920))  # Default bounds
	if game_scene:
		bounds_rect = Rect2(game_scene.global_position, game_scene.size)
	
	# Constrain bubble position to stay within bounds
	var constrained_pos = initial_bubble_pos
	
	# Check horizontal bounds
	if constrained_pos.x < bounds_rect.position.x:
		constrained_pos.x = bounds_rect.position.x + 5  # Add small margin
	elif constrained_pos.x + bubble_size.x > bounds_rect.position.x + bounds_rect.size.x:
		constrained_pos.x = bounds_rect.position.x + bounds_rect.size.x - bubble_size.x - 5
	
	# Check vertical bounds - if bubble would go above screen, position it below NPC instead
	if constrained_pos.y < bounds_rect.position.y:
		constrained_pos.y = npc_global_pos.y - scroll_offset.y + size.y + 5  # Position below NPC
	elif constrained_pos.y + bubble_size.y > bounds_rect.position.y + bounds_rect.size.y:
		constrained_pos.y = bounds_rect.position.y + bounds_rect.size.y - bubble_size.y - 5
	
	chat_bubble.position = constrained_pos

func hide_chat_bubble():
	if chat_bubble and is_instance_valid(chat_bubble):
		chat_bubble.hide_bubble()
		chat_bubble = null

func set_npc_data(data: Dictionary):
	npc_data = data
	npc_name = data.get("name", "Unknown NPC")
	
	# Set texture to npc.png
	var npc_texture_path = "res://assets/images/fallback/npc.png"
	if ResourceLoader.exists(npc_texture_path):
		texture = load(npc_texture_path)
