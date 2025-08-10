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
	print("NPC button pressed: ", npc_name)
	print("NPC data during click: ", npc_data)
	
	var quest_id = npc_data.get("questid", null)
	
	if quest_id != null:
		# NPC has a quest - directly show quest panel
		print("Found quest ID: ", quest_id, " - showing quest panel directly")
		
		# Find the quest panel directly
		var quest_panel = get_tree().current_scene.find_child("QuestPanel", true, false)
		if quest_panel and quest_panel.has_method("show_quest"):
			# Switch to home panel first
			var toggle_panel = get_tree().current_scene.find_child("Portrait", true, false)
			if toggle_panel and toggle_panel.has_method("show_panel"):
				var home_panel = toggle_panel.get("home_panel")
				if home_panel:
					toggle_panel.show_panel(home_panel)
					print("Switched to home panel")
			
			# Show the quest
			quest_panel.show_quest(npc_data)
			print("Quest panel shown directly for: ", npc_data.get("questname", "Unknown Quest"))
		else:
			print("Quest panel not found or missing show_quest method")
			# Fallback to signal emission
			npc_clicked.emit(self)
	else:
		# No quest - just show dialogue in chat bubble (already shown on hover)
		print("No quest found for NPC: ", npc_name)
	
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
	
	print("Setting NPC data for: ", npc_name)
	print("Quest ID in data: ", data.get("questid", "None"))
	print("Building ID in data: ", data.get("building", "None"))
	
	# Set texture to npc.png
	var npc_texture_path = "res://assets/images/fallback/npc.png"
	if ResourceLoader.exists(npc_texture_path):
		texture = load(npc_texture_path)
