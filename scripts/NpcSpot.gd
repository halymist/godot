extends Control
class_name NpcSpot

@export var spot_id: int = 1

var npc_data: Dictionary = {}
var npc_name: String = ""
var texture_rect: TextureRect
var spot_visual: Panel
var click_button: Button

var chat_bubble = null
@export var chat_bubble_scene: PackedScene
var linger_timer: Timer = null

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
		
		var quest_id = npc_data.get("questid", null)
		if quest_id != null and UIManager.instance:
			# NPC has a quest - show quest panel directly
			print("Showing quest panel for quest ID: ", quest_id)
			var quest_panel = UIManager.instance.quest_panel
			if quest_panel and quest_panel.has_method("show_quest"):
				quest_panel.show_quest(npc_data)
				GameInfo.set_current_panel_overlay(quest_panel)
		else:
			print("NPC has no quest - dialogue shown via chat bubble")

func _on_mouse_entered():
	if npc_data.size() > 0:
		var quest_id = npc_data.get("questid", null)
		
		if quest_id == null:
			# No quest - show dialogue as chat bubble
			show_chat_bubble()
		
		npc_hovered.emit(self)

func _on_mouse_exited():
	# Start linger timer - bubble will hide after 3 seconds
	if chat_bubble and is_instance_valid(chat_bubble):
		if linger_timer:
			linger_timer.queue_free()
		
		linger_timer = Timer.new()
		linger_timer.wait_time = 3.0
		linger_timer.one_shot = true
		linger_timer.timeout.connect(_on_linger_timeout)
		add_child(linger_timer)
		linger_timer.start()
	
	npc_hover_exited.emit(self)

func _on_linger_timeout():
	hide_chat_bubble()

func show_chat_bubble():
	# Cancel any pending linger timer
	if linger_timer and is_instance_valid(linger_timer):
		linger_timer.queue_free()
		linger_timer = null
	
	var dialogue = npc_data.get("dialogue", "...")
	
	# If bubble already exists and visible, just refresh it
	if chat_bubble and is_instance_valid(chat_bubble) and chat_bubble.visible:
		chat_bubble.show_dialogue(dialogue, 3.0, true)
		return
	
	if chat_bubble:
		hide_chat_bubble()
	
	chat_bubble = chat_bubble_scene.instantiate()
	
	# Add to parent (VillageContent) so it scrolls with the NPCs
	var parent = get_parent()
	if not parent:
		return
	
	parent.add_child(chat_bubble)
	
	# Show the dialogue and wait for it to finish sizing
	chat_bubble.show_dialogue(dialogue, 3.0)
	
	# Wait two frames to ensure size is fully calculated
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get bubble and NPC sizes
	var bubble_size = chat_bubble.size
	var npc_size = size
	
	# Find the ScrollContainer to get viewport info
	var scroll_container = parent.get_parent()
	var viewport_rect = Rect2(Vector2.ZERO, parent.size)
	
	if scroll_container is ScrollContainer:
		var scroll_offset = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
		viewport_rect = Rect2(scroll_offset, scroll_container.size)
	
	# Default: centered above NPC
	var bubble_x = position.x + (npc_size.x - bubble_size.x) / 2.0
	var bubble_y = position.y - bubble_size.y - 5  # 5px padding above NPC
	
	var margin = 5.0
	
	# Adjust horizontally if bubble goes outside viewport
	var bubble_left = bubble_x
	var bubble_right = bubble_x + bubble_size.x
	var viewport_left = viewport_rect.position.x
	var viewport_right = viewport_rect.position.x + viewport_rect.size.x
	
	if bubble_right > viewport_right:
		# Goes off right edge - shift left
		bubble_x = viewport_right - bubble_size.x - margin
	
	if bubble_left < viewport_left:
		# Goes off left edge - shift right
		bubble_x = viewport_left + margin
	
	# Check vertical bounds
	if bubble_y < viewport_rect.position.y:
		# Goes above viewport - position below NPC instead
		bubble_y = position.y + npc_size.y + 5
	
	if bubble_y + bubble_size.y > viewport_rect.position.y + viewport_rect.size.y:
		# Goes below viewport - clamp
		bubble_y = viewport_rect.position.y + viewport_rect.size.y - bubble_size.y - margin
	
	chat_bubble.position = Vector2(bubble_x, bubble_y)

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
