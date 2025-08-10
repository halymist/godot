extends Panel

# Preload the NPC class
const NPC = preload("res://scripts/NPC.gd")

@export var village_scene: Control
@export var interior_scene: Control
@export var npc_prefab: PackedScene

var current_building: String = ""
var is_in_interior: bool = false

# NPC data extracted from chat messages (we'll use the senders as NPCs)
var npcs_data = [
	{"name": "Herald", "status": "lord"},
	{"name": "Merchant Gareth", "status": "peasant"},
	{"name": "Guard Captain", "status": "guard"},
	{"name": "Alchemist Zara", "status": "peasant"},
	{"name": "Knight Commander", "status": "lord"},
	{"name": "Innkeeper Molly", "status": "peasant"},
	{"name": "Bard Lyra", "status": "peasant"},
	{"name": "Farmer Bob", "status": "peasant"},
	{"name": "Blacksmith Jane", "status": "peasant"}
]

func _ready():
	# Get references to child nodes
	village_scene = get_node("VillageView")
	interior_scene = get_node("InteriorView")
	
	# Set up initial state
	show_village()
	
	# Connect to existing buildings in the scene
	connect_existing_buildings()
	
	# Spawn NPCs in the village
	spawn_npcs()
	
	# Connect to the main back button
	call_deferred("connect_back_button")

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
		print("Warning: NPC prefab not assigned!")
		return
		
	var village_content = village_scene.get_node("ScrollContainer/VillageContent")
	
	# Spawn NPCs at random positions
	for i in range(npcs_data.size()):
		var npc_data = npcs_data[i]
		
		# Instance the NPC prefab
		var npc_instance = npc_prefab.instantiate()
		
		# Set random position in village (avoid building area)
		var random_x = randf_range(50, 400)
		var random_y = randf_range(50, 200)
		npc_instance.position = Vector2(random_x, random_y)
		npc_instance.size = Vector2(60, 80)
		
		# Set NPC data (no texture for now as requested)
		npc_instance.set_npc_data(npc_data.name, npc_data.status, null)
		
		# Connect the signal
		npc_instance.npc_clicked.connect(_on_npc_clicked)
		
		# Add to village
		village_content.add_child(npc_instance)
		
		print("Spawned NPC: ", npc_data.name, " (", npc_data.status, ")")

func _on_npc_clicked(npc: NPC):
	print("NPC clicked: ", npc.npc_name, " (Status: ", npc.status, ")")
	# TODO: Add NPC interaction logic here

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
