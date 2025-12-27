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

signal quest_accepted(quest_data: Dictionary)

func _ready():
	background_button.pressed.connect(_on_background_pressed)
	accept_button.pressed.connect(_on_accept_pressed)

func _on_background_pressed():
	hide_panel()

func _on_accept_pressed():
	quest_accepted.emit(current_quest_data)
	
	# Get quest ID from NPC data
	var quest_id = current_quest_data.get("questid", 0)
	
	print("=== Quest Accept Debug ===")
	print("Quest ID: ", quest_id)
	
	# Get quest definition from GameInfo to access travel data
	var quest_definition = GameInfo.get_quest_data(quest_id)
	print("Quest definition found: ", quest_definition != null)
	
	if quest_definition:
		print("Quest name: ", quest_definition.quest_name)
		print("Travel time: ", quest_definition.travel_time)
		print("Travel text: ", quest_definition.travel_text)
		
		var travel_time = quest_definition.travel_time
		if travel_time > 0:
			var current_time = Time.get_unix_time_from_system()
			var travel_end_time = current_time + (travel_time * 60) # Convert minutes to seconds
			
			# Update GameInfo with travel data
			GameInfo.current_player.traveling = travel_end_time
			GameInfo.accept_quest(quest_id)  # This sets traveling_destination
			
			print("Travel started - Duration: ", travel_time, " minutes, End time: ", travel_end_time)
			
			# Immediately update MapPanel if it exists
			if map and map.has_method("update_travel_display"):
				map.update_travel_display()
	else:
		print("ERROR: Quest definition not found for quest_id: ", quest_id)
		print("quests_db exists: ", GameInfo.quests_db != null)
		if GameInfo.quests_db:
			print("Number of quests in database: ", GameInfo.quests_db.quests.size())
	
	hide_panel()
	print("Quest accepted: ", current_quest_data.get("questname", "Unknown Quest"))
	
	# Switch to map panel directly through GameInfo
	if map:
		GameInfo.set_current_panel(map)
		map.visible = true
		print("Switched to map panel")
	else:
		print("Map panel reference not set")

func show_quest(quest_data: Dictionary):
	print("QuestPanel.show_quest called with data: ", quest_data)
	current_quest_data = quest_data
	
	# Display NPC name
	if npc_name_label:
		npc_name_label.text = quest_data.get("name", "Unknown NPC")
		print("Set NPC name: ", npc_name_label.text)
	else:
		print("npc_name_label is null")
	
	if quest_name_label:
		quest_name_label.text = quest_data.get("questname", "Unknown Quest")
		print("Set quest name: ", quest_name_label.text)
	else:
		print("quest_name_label is null")
	
	if quest_dialogue_label:
		quest_dialogue_label.text = quest_data.get("dialogue", "No dialogue available.")
		print("Set quest dialogue: ", quest_dialogue_label.text)
	else:
		print("quest_dialogue_label is null")
	
	# Load portrait texture
	if portrait_texture:
		var portrait = quest_data.get("portrait", null)
		if portrait is Texture2D:
			portrait_texture.texture = portrait
			print("Set portrait texture from resource")
		else:
			print("Portrait is not a valid Texture2D")
	else:
		print("portrait_texture is null")
	
	# Check if player is already traveling/has active quest
	var is_already_traveling = false
	if GameInfo.current_player:
		var has_active_travel = GameInfo.current_player.traveling > 0
		var has_destination = GameInfo.current_player.traveling_destination != null
		is_already_traveling = has_active_travel or has_destination
		print("Player travel state - traveling: ", has_active_travel, ", destination: ", has_destination, ", already traveling: ", is_already_traveling)
	
	# Show/hide accept button and already traveling label based on travel state
	if accept_button:
		accept_button.visible = not is_already_traveling
		print("Accept button visible: ", accept_button.visible)
	
	if alreadyTraveling:
		alreadyTraveling.visible = is_already_traveling
		print("Already traveling label visible: ", alreadyTraveling.visible)
	
	# Ensure quest panel is on top and visible
	z_index = 1000  # Very high z-index to appear above everything
	visible = true
	
	print("Quest panel set to visible: ", visible, " with z_index: ", z_index)

func hide_panel():
	visible = false
	GameInfo.set_current_panel_overlay(null)
	print("Quest panel hidden")
