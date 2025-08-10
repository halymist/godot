extends Panel

@export var village_scene: Control
@export var interior_scene: Control
@export var npc_prefab: PackedScene

var current_building: String = ""
var is_in_interior: bool = false
var quest_panel: Panel = null

func _ready():
	# Get references to child nodes
	village_scene = get_node("VillageView")
	interior_scene = get_node("InteriorView")
	
	# Get quest panel reference - search from game root
	quest_panel = get_tree().current_scene.find_child("QuestPanel", true, false)
	print("Quest panel found: ", quest_panel != null)
	if quest_panel:
		print("Quest panel path: ", quest_panel.get_path())
	
	# Set up initial state
	show_village()
	
	# Connect to existing buildings in the scene
	connect_existing_buildings()
	
	# Spawn NPCs in the village
	spawn_npcs()
	
	# Connect to the main back button
	call_deferred("connect_back_button")
	
	# Connect quest panel signals
	if quest_panel and quest_panel.has_method("quest_panel_closed"):
		quest_panel.quest_panel_closed.connect(_on_quest_panel_closed)
		quest_panel.quest_accepted.connect(_on_quest_accepted)
		print("Quest panel signal connected")

func connect_existing_buildings():
	var village_content = village_scene.get_node("ScrollContainer/VillageContent")
	
	# Connect signals for existing buildings in the scene
	for child in village_content.get_children():
		if child is Building:
			if not child.building_clicked.is_connected(_on_building_clicked):
				child.building_clicked.connect(_on_building_clicked)
			print("Connected existing building: ", child.building_name)

func spawn_npcs():
	if not npc_prefab:
		print("No NPC prefab assigned")
		return
		
	var village_content = village_scene.get_node("ScrollContainer/VillageContent")
	
	# Get NPC data from GameInfo
	var npcs_data = GameInfo.npcs
	
	# Spawn NPCs based on GameInfo data
	for i in range(npcs_data.size()):
		var npc_data = npcs_data[i]
		
		# Instance the NPC prefab
		var npc_instance = npc_prefab.instantiate()
		
		# Get village content size for anchor-based positioning
		var content_size = village_content.size
		if content_size == Vector2.ZERO:
			content_size = village_content.custom_minimum_size
		
		# Convert anchor-based position (0.0-1.0) to actual pixels
		var anchor_x = npc_data.get("xpos", randf_range(0.1, 0.9))  # Default random anchor
		var anchor_y = npc_data.get("ypos", randf_range(0.1, 0.8))  # Default random anchor
		var pixel_x = anchor_x * content_size.x
		var pixel_y = anchor_y * content_size.y
		npc_instance.position = Vector2(pixel_x, pixel_y)
		
		# Convert size multipliers to actual pixels (1.0 = base size of 60x80)
		var base_width = 60.0
		var base_height = 80.0
		var width_multiplier = npc_data.get("width", 1.0)
		var height_multiplier = npc_data.get("height", 1.0)
		var pixel_width = base_width * width_multiplier
		var pixel_height = base_height * height_multiplier
		npc_instance.size = Vector2(pixel_width, pixel_height)
		
		# Set the NPC data (texture is handled in NPC.gd)
		npc_instance.set_npc_data(npc_data)
		
		# Connect the signal
		npc_instance.npc_clicked.connect(_on_npc_clicked)
		
		# Add to village
		village_content.add_child(npc_instance)
		
		print("Spawned NPC: ", npc_data.get("name", "Unknown"), " at anchor (", anchor_x, ", ", anchor_y, ") = pixels (", pixel_x, ", ", pixel_y, ")")

func _on_npc_clicked(npc):
	print("NPC clicked: ", npc.npc_data.get("name", "Unknown"))
	
	var quest_id = npc.npc_data.get("questid", null)
	print("Quest ID: ", quest_id)
	
	if quest_id != null:
		# NPC has a quest - show quest panel
		print("Quest panel reference: ", quest_panel)
		if quest_panel:
			print("Quest panel has show_quest method: ", quest_panel.has_method("show_quest"))
			if quest_panel.has_method("show_quest"):
				quest_panel.show_quest(npc.npc_data)
				print("Showing quest panel for: ", npc.npc_data.get("questname", "Unknown Quest"))
			else:
				print("Quest panel missing show_quest method")
		else:
			print("Quest panel is null")
	else:
		# No quest - dialogue is already shown via hover chat bubble
		print("NPC has no quest - dialogue shown on hover")

func _on_quest_panel_closed():
	print("Quest panel closed")

func _on_quest_accepted(quest_data: Dictionary):
	print("Quest accepted: ", quest_data.get("questname", "Unknown Quest"))
	print("Quest travel time: ", quest_data.get("travel", 0))
	
	# Set current panel to map in GameInfo as well
	var toggle_panel = get_tree().current_scene.find_child("Portrait", true, false)
	if toggle_panel:
		var map_panel = toggle_panel.get("map_panel")
		if map_panel:
			GameInfo.set_current_panel(map_panel)
	
	# You can add quest acceptance logic here later

func handle_back_navigation() -> bool:
	# If we're in interior, go back to village
	if is_in_interior:
		show_village()
		return true
	# If we're in village, let the toggle panel handle it normally
	return false

func _on_building_clicked(building: Building):
	current_building = building.building_id
	show_interior(building)
	print("Entered building: ", building.building_id)

func show_village():
	is_in_interior = false
	village_scene.visible = true
	interior_scene.visible = false
	current_building = ""

func show_interior(building: Building = null):
	is_in_interior = true
	village_scene.visible = false
	interior_scene.visible = true
	
	# Let the building handle its own interior setup
	if building:
		building.show_interior()
	
	print("Inside building")

func connect_back_button():
	# Connect to back button functionality
	var toggle_panel = get_node("../../../TogglePanel")
	if toggle_panel and toggle_panel.has_method("set_village_manager"):
		toggle_panel.set_village_manager(self)
	
	# Also connect to the main back button for interior exit
	var back_button = get_node("../../../../TopUI/HBoxContainer/Back/Button")
	if back_button and not back_button.button_up.is_connected(_on_back_button_pressed):
		back_button.button_up.connect(_on_back_button_pressed)
		print("Connected back button for interior exit")

func _on_back_button_pressed():
	if is_in_interior:
		show_village()
		print("Exited interior to village")

func go_back():
	if is_in_interior:
		show_village()
	else:
		# Let the TogglePanel handle going back to previous screen
		pass
