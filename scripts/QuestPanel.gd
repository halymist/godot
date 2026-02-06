extends Panel
class_name QuestPanel

@export var quest_name_label: Label
@export var quest_dialogue_label: Label
@export var background_button: Button
@export var accept_button: Button
@export var portrait_texture: TextureRect
@export var map: Control
@export var alreadyTraveling: Label
@export var npc_name_label: Label

var current_quest_data: Dictionary = {}

func _ready():
	background_button.pressed.connect(UIManager.instance.hide_current_overlay)
	accept_button.pressed.connect(_on_accept_pressed)

func _on_accept_pressed():	
	# Get quest ID from NPC data
	var quest_id = current_quest_data.get("questid", 0)
	
	print("=== Quest Accept Debug ===")
	print("Quest ID: ", quest_id)
	
	# Get quest definition from database to access travel data
	var quest_definition = GameInfo.quests_db.get_quest_by_id(quest_id) if GameInfo.quests_db else null
	print("Quest definition found: ", quest_definition != null)
	
	if not quest_definition:
		print("ERROR: Quest definition not found for quest_id: ", quest_id)
		UIManager.instance.hide_current_overlay()
		return
	
	print("Quest name: ", quest_definition.quest_name)
	print("Travel text: ", quest_definition.travel_text)
	
	# Check if player is VIP
	var is_vip = GameInfo.current_player.vip if "vip" in GameInfo.current_player else false
	print("Player VIP status: ", is_vip)
	
	# Always set the quest destination first
	accept_quest(quest_id)  # This sets traveling_destination
	
	# Clear overlay stack so cancel button doesn't target quest_panel
	UIManager.instance.hide_current_overlay()
	
	# VIP: No timer (instant "Enter Quest" button)
	if is_vip:
		GameInfo.current_player.traveling = 0  # No timer for VIP
		print("VIP player - no timer")
	else:
		# Non-VIP: Start 10 second timer
		var travel_time = 10.0
		var current_time = Time.get_unix_time_from_system()
		var travel_end_time: float = current_time + travel_time
		
		# Update GameInfo with travel data (traveling is a timestamp)
		GameInfo.current_player.traveling = travel_end_time
		
		print("Travel started - Duration: ", travel_time, " seconds, End time: ", travel_end_time)
	
	# Go to map panel (VIP sees instant button, non-VIP sees timer)
	map.start_travel(quest_definition.travel_text, 10 if not is_vip else 0, quest_id)
	UIManager.instance.show_panel(map)
	print("Switched to map panel")

func show_quest(quest_data: Dictionary):
	print("QuestPanel.show_quest called with data: ", quest_data)
	current_quest_data = quest_data
	
	# Display NPC name
	npc_name_label.text = quest_data.get("name", "Unknown NPC")
	print("Set NPC name: ", npc_name_label.text)
	
	quest_name_label.text = quest_data.get("questname", "Unknown Quest")
	print("Set quest name: ", quest_name_label.text)
	
	quest_dialogue_label.text = quest_data.get("dialogue", "No dialogue available.")
	print("Set quest dialogue: ", quest_dialogue_label.text)
	
	# Load portrait texture
	var portrait = quest_data.get("portrait", null)
	if portrait is Texture2D:
		portrait_texture.texture = portrait
		print("Set portrait texture from resource")
	else:
		print("Portrait is not a valid Texture2D")
	
	# Check if player is already traveling/has active quest
	var is_already_traveling = false
	var has_active_travel = GameInfo.current_player.traveling > 0
	var has_destination = GameInfo.current_player.traveling_destination != null
	is_already_traveling = has_active_travel or has_destination
	print("Player travel state - traveling: ", has_active_travel, ", destination: ", has_destination, ", already traveling: ", is_already_traveling)
	
	# Show/hide accept button and already traveling label based on travel state
	accept_button.visible = not is_already_traveling
	print("Accept button visible: ", accept_button.visible)
	
	alreadyTraveling.visible = is_already_traveling
	print("Already traveling label visible: ", alreadyTraveling.visible)
	
	# Show this panel as an overlay
	UIManager.instance.show_overlay(self)
	print("Quest panel shown as overlay with z_index: ", z_index)

func accept_quest(quest_id: int):
	Websocket.accept_quest(quest_id)
	GameInfo.current_player.traveling_destination = quest_id
	print("Player accepted quest ", quest_id, " and is now traveling to it")
