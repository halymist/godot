extends Panel

# Export references
@export var quest_panel: Control  # Old accept quest panel
@export var quest_slide_panel: Control  # New quest slide panel (DynamicOptionsPanel)
@export var map_panel: Control

var current_village_node: Control = null  # Current active village instance
var current_building: Building = null
var is_in_interior: bool = false
var village_scroll_initialized: bool = false  # Track if village scroll has been centered initially

func _ready():
	print("=== VillageManager _ready START ===")
	
	# Connect signals FIRST - these work regardless of character selection
	GameInfo.character_changed.connect(_on_character_changed)
	GameInfo.quest_completed.connect(_on_quest_completed)
	print("Connected to quest completed signal")
	
	# Don't initialize village until character is selected
	if not GameInfo.current_player:
		print("No character selected yet - waiting for selection")
		return
	
	var location_id = GameInfo.current_player.location
	print("Location ID from current_player: ", location_id)
	
	# Load village based on current player location
	set_active_village(location_id)
	
	show_village()
	connect_existing_buildings()
	spawn_npcs()
	
	# Center scroll position only on first startup
	if not village_scroll_initialized:
		await get_tree().process_frame
		if current_village_node:
			var village_view = current_village_node.get_node("VillageView")
			var village_content = village_view.get_node("VillageContent")
			var content_width = village_content.size.x
			var viewport_width = village_view.size.x
			village_view.scroll_horizontal = int((content_width - viewport_width) / 2.0)
			village_scroll_initialized = true
	
	# Connect quest panel signals
	quest_panel.quest_accepted.connect(_on_quest_accepted)
	print("=== VillageManager _ready END ===")

func _on_character_changed():
	print("VillageManager: Character changed, refreshing village")
	var location_id = GameInfo.current_player.location
	set_active_village(location_id)
	show_village()
	connect_existing_buildings()
	spawn_npcs()

func set_active_village(location_id: int):
	"""Set the active village based on location integer (1, 2, 3, etc.)"""
	print("=== set_active_village START ===")
	print("  location_id: ", location_id)
	
	# Clear any existing village nodes
	for child in get_children():
		if child != quest_panel and child != quest_slide_panel and child != map_panel:
			print("  Removing old child: ", child.name)
			child.queue_free()
	
	# Load village scene from settlements database
	print("  Getting location data from settlements_db...")
	var location_data = GameInfo.get_location_data(location_id)
	if not location_data:
		print("  ERROR: No location data found for location_id: ", location_id)
		print("  settlements_db exists: ", GameInfo.settlements_db != null)
		if GameInfo.settlements_db:
			print("  settlements count: ", GameInfo.settlements_db.settlements.size())
		return
	
	print("  Location data found: ", location_data.location_name)
	
	if not location_data.village_scene:
		print("  ERROR: No village scene assigned for location: ", location_data.location_name)
		return
	
	print("  Instantiating village scene...")
	# Instantiate the village scene and add it at index 0 (behind other panels)
	var village_instance = location_data.village_scene.instantiate()
	add_child(village_instance)
	move_child(village_instance, 0)  # Move to first position so it renders behind quest panels
	current_village_node = village_instance
	print("  Village loaded successfully: ", location_data.location_name)
	print("  Village instance: ", village_instance.name)
	print("=== set_active_village END ===")

func connect_existing_buildings():
	if not current_village_node:
		return
		
	var village_view = current_village_node.get_node("VillageView")
	var village_content = village_view.get_node("VillageContent")
	
	# Connect signals for existing buildings in the scene
	for child in village_content.get_children():
		if child is Building:
			if not child.building_clicked.is_connected(_on_building_clicked):
				child.building_clicked.connect(_on_building_clicked)
			print("Connected existing building: ", child.building_name)

func spawn_npcs(building_id: int = 0):
	if not GameInfo.npcs_db:
		print("No NPC database loaded")
		return
	
	if not current_village_node:
		return
	
	var village_view = current_village_node.get_node("VillageView")
	var village_content = village_view.get_node("VillageContent")
	
	# Get NPCs to spawn based on daily quests and quest log
	var daily_quests = GameInfo.current_player.daily_quests if GameInfo.current_player else []
	var quest_log = GameInfo.current_player.quest_log if GameInfo.current_player else []
	var npcs_to_spawn = GameInfo.npcs_db.get_npcs_for_quests(daily_quests, quest_log, building_id)
	
	print("Spawning ", npcs_to_spawn.size(), " NPCs for building ", building_id)
	
	# Determine where to spawn (village or interior)
	var parent_container = village_content
	if building_id > 0 and current_building and current_building.interior_content:
		parent_container = current_building.interior_content
		print("Spawning in interior: ", current_building.building_name)
	
	# Spawn each NPC at their designated spot
	for npc_resource in npcs_to_spawn:
		# Find the spot node
		var spot_name = "Spot" + str(npc_resource.spot)
		var spot_node = parent_container.get_node_or_null(spot_name)
		
		if not spot_node:
			print("Warning: Spot node '", spot_name, "' not found for NPC '", npc_resource.name, "' in ", parent_container.name)
			continue
		
		if not spot_node is NpcSpot:
			print("Warning: Spot node '", spot_name, "' is not an NpcSpot")
			continue
		
		# Check if this NPC has a quest dialogue for any daily quest
		var quest_dialogue: QuestDialogueEntry = null
		var quest_finished = false
		var clicked_options = []
		
		for quest_id in daily_quests:
			quest_dialogue = npc_resource.get_quest_dialogue(quest_id)
			if quest_dialogue:
				# Check if quest is finished in quest_log
				for quest_entry in quest_log:
					if quest_entry.get("quest_id", 0) == quest_id:
						quest_finished = quest_entry.get("finished", false)
						clicked_options = quest_entry.get("clicked_options", [])
						break
				break
		
		var npc_data = {}
		
		if quest_dialogue and not quest_finished:
			# Quest not finished - show quest dialogue
			npc_data = {
				"name": npc_resource.name,
				"asset": npc_resource.asset.resource_path if npc_resource.asset else "",
				"portrait": npc_resource.portrait,
				"dialogue": quest_dialogue.text,
				"questid": quest_dialogue.quest_id,
				"questname": quest_dialogue.name,
				"building": npc_resource.building_id
			}
		else:
			# Quest finished or no quest - show normal dialogue
			var normal_dialogue = npc_resource.get_normal_dialogue_for_options(clicked_options)
			npc_data = {
				"name": npc_resource.name,
				"asset": npc_resource.asset.resource_path if npc_resource.asset else "",
				"portrait": npc_resource.portrait,
				"dialogue": normal_dialogue.text if normal_dialogue else "...",
				"questid": null,
				"questname": "",
				"building": npc_resource.building_id
			}
		
		# Set the NPC data on the spot
		spot_node.set_npc_data(npc_data)
		
		print("Spawned NPC: ", npc_resource.name, " at spot ", npc_resource.spot, " in building ", building_id)

func handle_npc_clicked(npc):
	"""Called directly from NPC/NpcSpot when clicked"""
	print("=== VillageManager.handle_npc_clicked() CALLED ===")
	print("Clicked NPC: ", npc.npc_data.get("name", "Unknown"))
	print("Is in interior: ", is_in_interior)
	print("Current building: ", current_building)
	
	var quest_id = npc.npc_data.get("questid", null)	
	if quest_id != null:
		# NPC has a quest - show quest panel
		print("Showing quest panel for quest ID: ", quest_id)
		quest_panel.show_quest(npc.npc_data)
		UIManager.instance.show_overlay(quest_panel)
	else:
		# NPC has no quest - just show dialogue in chat bubble (handled by NPC itself on hover)
		print("No quest for this NPC - dialogue shown via chat bubble")
		# Could add more dialogue interaction here if needed


func _on_quest_accepted(quest_data: Dictionary):
	print("Quest accepted: ", quest_data.get("questname", "Unknown Quest"))
	
	# Get quest ID from NPC data
	var quest_id = quest_data.get("questid", 0)
	
	# Get quest definition from GameInfo to access travel data
	var quest_definition = GameInfo.get_quest_data(quest_id)
	if quest_definition:
		var travel_text = quest_definition.travel_text if quest_definition.travel_text else "Traveling to quest..."
		var travel_seconds = 20  # Always 20 seconds
		
		print("Quest travel time: ", travel_seconds, " seconds")
		
		# Pass travel info to MapPanel
		map_panel.start_travel(travel_text, travel_seconds, quest_id)
	
	GameInfo.set_current_panel(map_panel)

func _on_quest_completed(quest_id: int):
	"""Handle quest completion by redrawing NPCs"""
	print("Quest ", quest_id, " completed - redrawing NPCs")
	redraw_npcs()

func redraw_npcs():
	"""Clear and respawn all NPCs in current location"""
	# Determine where to clear NPCs from
	var parent_container
	var building_id = 0
	
	if is_in_interior and current_building:
		parent_container = current_building.interior_content
		building_id = int(current_building.building_id)
	else:
		parent_container = current_village_node.get_node("VillageView/VillageContent")
		building_id = 0
	
	# Clear all NPC spots in current location
	for child in parent_container.get_children():
		if child is NpcSpot:
			child.clear_npc()
	
	# Respawn NPCs for current location
	spawn_npcs(building_id)

func handle_back_navigation() -> bool:
	# If we're in interior, go back to village
	if is_in_interior:
		show_village()
		return true
	# If we're in village, let the toggle panel handle it normally
	return false

func _on_building_clicked(building: Building):
	current_building = building
	show_interior(building)
	print("Entered building: ", building.building_name)

func show_village():
	is_in_interior = false
	
	if current_village_node:
		var village_view = current_village_node.get_node("VillageView")
		var interior_view = current_village_node.get_node("InteriorView")
		village_view.visible = true
		interior_view.visible = false
	
	# Hide current building's interior content
	if current_building and current_building.interior_content:
		current_building.interior_content.visible = false
	
	current_building = null

func show_interior(building: Building = null):
	is_in_interior = true
	
	if current_village_node:
		var village_view = current_village_node.get_node("VillageView")
		var interior_view = current_village_node.get_node("InteriorView")
		village_view.visible = false
		interior_view.visible = true
	
	current_building = building
	
	if building and building.interior_content:
		# Show this building's interior content
		building.interior_content.visible = true
		
		# Spawn NPCs for this building
		var building_int_id = int(building.building_id)
		spawn_npcs(building_int_id)
		
		# Center the scroll position when entering
		await get_tree().process_frame  # Wait for layout update
		if current_village_node:
			var interior_view = current_village_node.get_node("InteriorView")
			var content_width = building.interior_content.size.x
			var viewport_width = interior_view.size.x
			interior_view.scroll_horizontal = int((content_width - viewport_width) / 2.0)
		
		print("Showing interior for: ", building.building_name)
	else:
		print("Warning: No interior_content assigned to building")
	
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

func center_village_view():
	"""Center the village scroll view"""
	if current_village_node:
		await get_tree().process_frame
		var village_view = current_village_node.get_node("VillageView")
		var village_content = village_view.get_node("VillageContent")
		var content_width = village_content.size.x
		var viewport_width = village_view.size.x
		village_view.scroll_horizontal = int((content_width - viewport_width) / 2.0)
