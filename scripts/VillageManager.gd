extends Panel

# Export references to village containers
# Structure: Home -> Village1, Village2, etc. (each contains VillageView + InteriorView)
@export var villages_container: Control  # Parent node containing all village nodes
@export var quest_panel: Control  # Old accept quest panel
@export var quest_slide_panel: Control  # New quest slide panel (DynamicOptionsPanel)
@export var map_panel: Control

var current_village_node: Control = null  # Current active village (Village1, Village2, etc.)
var current_building: Building = null
var is_in_interior: bool = false
var village_scroll_initialized: bool = false  # Track if village scroll has been centered initially

func _ready():
	# Set current village based on player location
	var player_location = GameInfo.current_player.location if GameInfo.current_player else 1
	print("VillageManager: Player location from GameInfo: ", player_location)
	set_active_village(player_location)
	
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
	
	# Connect global NPC click signal
	GameInfo.npc_clicked.connect(_on_npc_clicked)
	print("Connected to global NPC click signal")
	
	# Connect quest completed signal to redraw NPCs
	GameInfo.quest_completed.connect(_on_quest_completed)
	print("Connected to quest completed signal")

func set_active_village(location_id: int):
	"""Set the active village based on location integer (1, 2, 3, etc.)"""
	print("set_active_village called with location_id: ", location_id)
	
	if not villages_container:
		print("Error: villages_container not assigned")
		return
	
	# Hide all villages first
	for village in villages_container.get_children():
		village.visible = false
	
	# Show the village matching the location ID
	var village_name = "Village" + str(location_id)
	var village_node = villages_container.get_node_or_null(village_name)
	
	if village_node:
		village_node.visible = true
		current_village_node = village_node
		print("Switched to village: ", village_name)
	else:
		print("Warning: Village node '", village_name, "' not found for location ", location_id)
		# Fallback to first village if exists
		if villages_container.get_child_count() > 0:
			current_village_node = villages_container.get_child(0)
			current_village_node.visible = true
			print("Using fallback village: ", current_village_node.name)

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
		
		# Find appropriate dialogue based on quest state
		var dialogue_entry = get_appropriate_dialogue(npc_resource, quest_log)
		
		# Get quest name if this is a quest dialogue
		var quest_name = ""
		if dialogue_entry and dialogue_entry.isQuest:
			var quest_data = GameInfo.get_quest_data(dialogue_entry.questID)
			if quest_data:
				quest_name = quest_data.get("quest_name", "Unknown Quest")
		
		var npc_data = {
			"name": npc_resource.name,
			"asset": npc_resource.asset.resource_path if npc_resource.asset else "",
			"portrait": npc_resource.portrait,  # Pass the Texture2D directly
			"dialogue": dialogue_entry.dialogue if dialogue_entry else "...",
			"questid": dialogue_entry.questID if dialogue_entry and dialogue_entry.isQuest else null,
			"questname": quest_name,
			"building": npc_resource.building_id
		}
		
		# Set the NPC data on the spot
		spot_node.set_npc_data(npc_data)
		
		print("Spawned NPC: ", npc_resource.name, " at spot ", npc_resource.spot, " in building ", building_id)

func get_appropriate_dialogue(npc_resource: NpcResource, quest_log: Array) -> DialogueEntry:
	"""Find the appropriate dialogue for the NPC based on quest state"""
	for dialogue in npc_resource.dialogues:
		var quest_id = dialogue.questID
		var stage = dialogue.stage
		
		# Check if player is at this quest stage
		for quest_entry in quest_log:
			if quest_entry.get("quest_id", 0) == quest_id:
				var slides = quest_entry.get("slides", [])
				if stage in slides or (stage == 0 and slides.is_empty()):
					return dialogue
	
	# Return first dialogue as default if no match
	if npc_resource.dialogues.size() > 0:
		return npc_resource.dialogues[0]
	return null

func _on_npc_clicked(npc):
	print("=== VillageManager._on_npc_clicked() CALLED ===")
	print("Clicked NPC: ", npc.npc_data.get("name", "Unknown"))
	print("Is in interior: ", is_in_interior)
	print("Current building: ", current_building)
	
	var quest_id = npc.npc_data.get("questid", null)	
	if quest_id != null:
		# NPC has a quest - show quest panel
		print("Showing quest panel for quest ID: ", quest_id)
		quest_panel.show_quest(npc.npc_data)
		GameInfo.set_current_panel_overlay(quest_panel)
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
		var travel_text = quest_definition.get("travel_text", "Traveling to quest...")
		var travel_minutes = quest_definition.get("travel_time", 5)
		
		print("Quest travel time: ", travel_minutes)
		
		# Pass travel info to MapPanel
		map_panel.start_travel(travel_text, travel_minutes)
	
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
