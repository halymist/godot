extends Panel
class_name QuestPanel

@export var quest_name_label: Label
@export var quest_dialogue_label: Label
@export var background_button: Button
@export var accept_button: Button
@export var portrait_texture: TextureRect
@export var map: Control

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
		if map and map.has_method("update_travel_display"):
			map.update_travel_display()
	
	hide_panel()
	print("Quest accepted: ", current_quest_data.get("questname", "Unknown Quest"))
	
	# Switch to map panel through the TogglePanel
	var toggle_panel = get_tree().current_scene.find_child("Portrait", true, false)
	if toggle_panel and toggle_panel.has_method("show_panel"):
		if map:
			toggle_panel.show_panel(map)
			print("Switched to map panel")
		else:
			print("Map panel reference not set")

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
	
	# Ensure quest panel is on top and visible with smooth transition
	z_index = 1000  # Very high z-index to appear above everything
	
	# Start with transparent and animate in
	modulate = Color(1, 1, 1, 0)
	visible = true
	
	# Smooth fade-in animation
	var show_tween = create_tween()
	show_tween.set_ease(Tween.EASE_OUT)
	show_tween.set_trans(Tween.TRANS_CUBIC)
	show_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	
	print("Quest panel set to visible: ", visible, " with z_index: ", z_index)

func hide_panel():
	# Smooth fade-out animation before hiding
	var hide_tween = create_tween()
	hide_tween.set_ease(Tween.EASE_IN)
	hide_tween.set_trans(Tween.TRANS_CUBIC)
	hide_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.2)
	hide_tween.tween_callback(_finish_hide)

func _finish_hide():
	visible = false
	quest_panel_closed.emit()
	print("Quest panel hidden")
