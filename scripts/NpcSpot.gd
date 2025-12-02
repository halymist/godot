extends Control
class_name NpcSpot

@export var spot_id: int = 1

var npc_data: Dictionary = {}
var npc_name: String = ""
var texture_rect: TextureRect
var spot_visual: Panel
var click_button: Button

var chat_bubble: Panel = null
var chat_bubble_scene = preload("res://Scenes/ChatBubble.tscn")

signal npc_hovered(npc: NpcSpot)
signal npc_hover_exited(npc: NpcSpot)

func _ready():
	# Get references
	texture_rect = $AspectRatioContainer/NPCTexture
	spot_visual = $AspectRatioContainer/SpotVisual
	click_button = $AspectRatioContainer/ClickButton
	
	# In editor, show spot visual. In game, hide until NPC spawns
	if Engine.is_editor_hint():
		spot_visual.visible = true
		texture_rect.visible = false
		if click_button:
			click_button.visible = false
	else:
		spot_visual.visible = false
		texture_rect.visible = false
		# Empty spots should not block mouse input
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if click_button:
			click_button.visible = false
			# Connect button signals
			click_button.button_up.connect(_on_button_pressed)
			click_button.mouse_entered.connect(_on_mouse_entered)
			click_button.mouse_exited.connect(_on_mouse_exited)

func _on_button_pressed():
	if npc_data.size() > 0:
		print("NPC button pressed: ", npc_name)
		print("NPC data during click: ", npc_data)
		# Emit global signal through GameInfo
		GameInfo.emit_signal("npc_clicked", self)
		print("Emitted npc_clicked signals for: ", npc_name)

func _on_mouse_entered():
	if npc_data.size() > 0:
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
	
	# Add to scene root
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
	
	# Now position bubble directly above NPC with minimal padding
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
	
	if data.has("asset") and data["asset"] != "" and texture_rect:
		var tex = load(data["asset"])
		texture_rect.texture = tex
		texture_rect.visible = true
		spot_visual.visible = false
		# Enable mouse input when NPC is present
		mouse_filter = Control.MOUSE_FILTER_STOP
		if click_button:
			click_button.visible = true

func clear_npc():
	npc_data = {}
	npc_name = ""
	if texture_rect:
		texture_rect.texture = null
		texture_rect.visible = false
	if click_button:
		click_button.visible = false
	spot_visual.visible = false
	# Disable mouse input when empty
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Disable mouse input when empty
	mouse_filter = Control.MOUSE_FILTER_IGNORE
