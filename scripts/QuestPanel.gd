extends Panel
class_name QuestPanel

@export var quest_name_label: Label
@export var quest_dialogue_label: Label
@export var background_button: Button
@export var accept_button: Button
@export var portrait_texture: TextureRect

var current_quest_data: Dictionary = {}

signal quest_panel_closed()
signal quest_accepted(quest_data: Dictionary)

func _ready():
	if background_button:
		background_button.pressed.connect(_on_background_pressed)
	
	if accept_button:
		accept_button.pressed.connect(_on_accept_pressed)

func _on_background_pressed():
	hide_panel()

func _on_accept_pressed():
	quest_accepted.emit(current_quest_data)
	
	# Set travel data when accepting quest
	var travel_time = current_quest_data.get("travel", 0)
	if travel_time > 0:
		var current_time = Time.get_unix_time_from_system()
		var travel_end_time = current_time + (travel_time * 60) # Convert minutes to seconds
		
		# Update GameInfo with travel data
		GameInfo.current_player.traveling = travel_end_time
		GameInfo.current_player.traveling_destination = current_quest_data.get("questid", 0)
		
		print("Travel started - Duration: ", travel_time, " minutes, End time: ", travel_end_time)
		
		# Immediately update MapPanel if it exists
		var map_panel = get_tree().current_scene.find_child("Map", true, false)
		if map_panel and map_panel.has_method("update_travel_display"):
			map_panel.update_travel_display()
	
	hide_panel()
	print("Quest accepted: ", current_quest_data.get("questname", "Unknown Quest"))
	
	# Switch to map panel through the TogglePanel
	var toggle_panel = get_tree().current_scene.find_child("Portrait", true, false)
	if toggle_panel and toggle_panel.has_method("show_panel"):
		var map_panel = toggle_panel.get("map_panel")
		if map_panel:
			toggle_panel.show_panel(map_panel)
			print("Switched to map panel")

func show_quest(quest_data: Dictionary):
	print("QuestPanel.show_quest called with data: ", quest_data)
	current_quest_data = quest_data
	
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
		var portrait_name = quest_data.get("portrait", "npc_portrait")
		var portrait_path = "res://assets/images/fallback/" + portrait_name + ".png"
		if ResourceLoader.exists(portrait_path):
			portrait_texture.texture = load(portrait_path)
			print("Loaded portrait: ", portrait_path)
		else:
			print("Portrait not found: ", portrait_path)
	else:
		print("portrait_texture is null")
	
	visible = true
	print("Quest panel set to visible: ", visible)

func hide_panel():
	visible = false
	quest_panel_closed.emit()
