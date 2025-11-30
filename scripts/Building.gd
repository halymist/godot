extends Control
class_name Building

@export var building_id: String = ""
@export var building_name: String = ""
@export var interior_content: TextureRect  # Reference to this building's interior TextureRect in InteriorView
@export var npc_prefab: PackedScene  # NPC prefab for spawning

@onready var click_button: Button = $ClickButton
@onready var hover_area: ColorRect = $HoverArea

signal building_clicked(building: Building)

var spawned_npcs: Array = []

func _ready():
	# Connect the button press signal
	click_button.button_up.connect(_on_button_pressed)
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)
	
	# Load NPC prefab if not assigned
	if not npc_prefab:
		npc_prefab = preload("res://Scenes/NPC.tscn")

func _on_mouse_entered():
	hover_area.color = Color(1, 1, 1, 0.3)  # White overlay with 30% opacity

func _on_mouse_exited():
	hover_area.color = Color(1, 1, 1, 0)  # Transparent

func _on_button_pressed():
	building_clicked.emit(self)

func spawn_building_npcs():
	# Clear existing NPCs
	clear_spawned_npcs()
	
	if not npc_prefab:
		print("Cannot spawn NPCs - missing prefab")
		return
	
	if not interior_content:
		print("Cannot spawn NPCs - interior_content not assigned")
		return
	
	# Get NPCs for this building from GameInfo
	var npcs_data = GameInfo.npcs
	var building_int_id = int(building_id)  # Convert string ID to int for comparison
	
	for npc_data in npcs_data:
		var npc_building_id = npc_data.get("building", 0)
		
		# Only spawn NPCs that belong to this building
		if npc_building_id == building_int_id:
			# Check dependency requirements (if NPC requires a quest slide to be visited)
			var dependency_quest = npc_data.get("dependency_quest", null)
			var dependency_slide = npc_data.get("dependency_slide", null)
			if dependency_quest != null and dependency_slide != null:
				# This NPC requires a specific quest slide to be visited
				if not GameInfo.has_visited_quest_slide(dependency_quest, dependency_slide):
					print("Skipping NPC (dependency not met): ", npc_data.get("name", "Unknown"), " (Requires Quest ", dependency_quest, " Slide ", dependency_slide, ")")
					continue
			
			# Skip NPCs whose quests are completed
			var npc_quest_id = npc_data.get("questid", null)
			if npc_quest_id != null and GameInfo.is_quest_completed(npc_quest_id):
				print("Skipping NPC with completed quest: ", npc_data.get("name", "Unknown"), " (Quest ID: ", npc_quest_id, ")")
				continue
			
			var npc_instance = npc_prefab.instantiate()
			
			# Position NPC within the building interior
			var content_size = interior_content.size
			if content_size == Vector2.ZERO:
				content_size = interior_content.custom_minimum_size
			
			# Use anchor-based positioning within the building
			var anchor_x = npc_data.get("xpos", 0.5)
			var anchor_y = npc_data.get("ypos", 0.5)
			var pixel_x = anchor_x * content_size.x
			var pixel_y = anchor_y * content_size.y
			npc_instance.position = Vector2(pixel_x, pixel_y)
			
			# Set NPC size
			var base_width = 60.0
			var base_height = 80.0
			var width_multiplier = npc_data.get("width", 1.0)
			var height_multiplier = npc_data.get("height", 1.0)
			npc_instance.size = Vector2(base_width * width_multiplier, base_height * height_multiplier)
			
			# Set NPC data
			npc_instance.set_npc_data(npc_data)
			
			# NPC will emit global signal through GameInfo - no need to connect here
			print("NPC ", npc_data.get("name", "Unknown"), " will use global signal")
			
			# Add to building interior
			interior_content.add_child(npc_instance)
			spawned_npcs.append(npc_instance)
			
			print("Spawned NPC ", npc_data.get("name", "Unknown"), " in building ", building_id)

func clear_spawned_npcs():
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	spawned_npcs.clear()
