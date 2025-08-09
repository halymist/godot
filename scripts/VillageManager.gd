extends Panel

@export var village_scene: Control
@export var interior_scene: Control

var current_building: String = ""
var is_in_interior: bool = false

# Scroll controls
var is_dragging: bool = false
var drag_start_position: Vector2
var scroll_start_position: Vector2
var current_scroll_container: ScrollContainer

# NPC data structure (mock data based on server format)
var npcs: Array[Dictionary] = []

# Building data - you can expand this later
# Building data
var buildings = {
	"blacksmith": {"name": "Blacksmith"},
	"tavern": {"name": "Tavern"},
	"shop": {"name": "General Store"},
	"inn": {"name": "Inn"},
	"market": {"name": "Market"},
	"bank": {"name": "Bank"},
	"temple": {"name": "Temple"},
	"guild": {"name": "Guild Hall"},
	"stables": {"name": "Stables"},
	"library": {"name": "Library"}
}

func _ready():
	# Get references to child nodes
	village_scene = get_node("VillageView")
	interior_scene = get_node("InteriorView")
	
	# Set up initial state
	show_village()
	
	# Connect building buttons
	connect_building_buttons()
	
	# Connect to the main back button
	call_deferred("connect_back_button")

func create_mock_npcs():
	# Mock NPC data based on server structure
	npcs = [
		{
			"name": "Village Blacksmith",
			"xpos": 0.2,  # 20% across the village width
			"ypos": 0.4,  # 40% down the village height
			"width": 1.0,  # Normal width
			"height": 1.0,  # Normal height
			"dialogue": "Welcome to my forge! I can craft weapons and armor.",
			"questid": null,
			"questname": null,
			"questtravel": null,
			"building": "village",  # In the main village
			"asset": "blacksmith_npc",
			"traveltext": null
		},
		{
			"name": "Tavern Keeper",
			"xpos": 0.15,
			"ypos": 0.3,
			"width": 1.2,  # Slightly wider
			"height": 0.9,  # Slightly shorter
			"dialogue": "Ale's fresh and the rooms are warm!",
			"questid": 1,
			"questname": "Lost Shipment",
			"questtravel": null,
			"building": "tavern",
			"asset": "tavern_keeper",
			"traveltext": null
		},
		{
			"name": "Merchant",
			"xpos": 0.6,
			"ypos": 0.5,
			"width": 0.8,  # Smaller
			"height": 1.1,  # Taller
			"dialogue": "I have the finest goods from distant lands!",
			"questid": null,
			"questname": null,
			"questtravel": 2,  # Can travel to area 2
			"building": "village",
			"asset": "merchant_npc",
			"traveltext": "Want to travel to the Eastern Markets?"
		},
		{
			"name": "Shop Assistant",
			"xpos": 0.7,
			"ypos": 0.2,
			"width": 1.0,
			"height": 1.0,
			"dialogue": "Need supplies? We have everything!",
			"questid": null,
			"questname": null,
			"questtravel": null,
			"building": "shop",
			"asset": "assistant_npc",
			"traveltext": null
		}
	]

func setup_scroll_containers():
	# Hide scrollbars and enable drag scrolling
	var village_scroll = village_scene.get_node("ScrollContainer")
	var interior_scroll = interior_scene.get_node("ScrollContainer")
	
	# Hide scrollbars
	village_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	village_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	interior_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	interior_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	# Connect input events for drag scrolling
	village_scroll.gui_input.connect(_on_scroll_input)
	interior_scroll.gui_input.connect(_on_scroll_input)

func connect_building_buttons():
	# Connect the building buttons that are in the scene
	var village_content = village_scene.get_node("ScrollContainer/VillageContent")
	
	var building_names = ["Blacksmith", "Tavern", "Shop", "Inn", "Market", "Bank", "Temple", "Guild", "Stables", "Library"]
	var building_ids = ["blacksmith", "tavern", "shop", "inn", "market", "bank", "temple", "guild", "stables", "library"]
	
	for i in range(building_names.size()):
		if village_content.has_node(building_names[i]):
			village_content.get_node(building_names[i]).pressed.connect(_on_building_clicked.bind(building_ids[i]))

func create_npcs():
	# Create NPCs based on mock data
	for npc_data in npcs:
		if npc_data.building == "village":
			create_npc_in_scene(npc_data, village_scene.get_node("ScrollContainer/VillageContent"))
		elif npc_data.building in buildings:
			# Will be created when entering the specific building interior
			pass

func create_npc_in_scene(npc_data: Dictionary, parent_node: Control):
	# Calculate position based on percentage and parent size
	var parent_size = parent_node.custom_minimum_size
	var npc_pos = Vector2(
		npc_data.xpos * parent_size.x,
		npc_data.ypos * parent_size.y
	)
	
	# Create NPC button
	var npc_button = Button.new()
	npc_button.name = npc_data.name.replace(" ", "_")
	npc_button.text = npc_data.name
	
	# Calculate size with factors (base size 80x100)
	var base_size = Vector2(80, 100)
	npc_button.size = Vector2(
		base_size.x * npc_data.width,
		base_size.y * npc_data.height
	)
	npc_button.position = npc_pos
	
	# Style the NPC button
	npc_button.flat = false
	npc_button.add_theme_color_override("font_color", Color.YELLOW)
	npc_button.add_theme_color_override("font_color_hover", Color.WHITE)
	npc_button.add_theme_font_size_override("font_size", 12)
	
	# Connect NPC interaction
	npc_button.pressed.connect(_on_npc_clicked.bind(npc_data))
	
	parent_node.add_child(npc_button)

func _on_npc_clicked(npc_data: Dictionary):
	print("Talking to: ", npc_data.name)
	print("Dialogue: ", npc_data.dialogue)
	
	# Handle different NPC types
	if npc_data.questid != null:
		print("Quest available: ", npc_data.questname)
	
	if npc_data.questtravel != null:
		print("Travel option: ", npc_data.traveltext)

func _on_scroll_input(event: InputEvent):
	var scroll_container = null
	
	# Determine which scroll container is active
	if village_scene.visible:
		scroll_container = village_scene.get_node("ScrollContainer")
	elif interior_scene.visible:
		scroll_container = interior_scene.get_node("ScrollContainer")
	
	if not scroll_container:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_position = event.global_position
				scroll_start_position = Vector2(scroll_container.scroll_horizontal, scroll_container.scroll_vertical)
				current_scroll_container = scroll_container
			else:
				is_dragging = false
				current_scroll_container = null
	
	elif event is InputEventMouseMotion and is_dragging:
		if current_scroll_container:
			var drag_delta = drag_start_position - event.global_position
			current_scroll_container.scroll_horizontal = scroll_start_position.x + drag_delta.x
			current_scroll_container.scroll_vertical = scroll_start_position.y + drag_delta.y

func _on_building_clicked(building_id: String):
	current_building = building_id
	show_interior(building_id)

func show_village():
	is_in_interior = false
	village_scene.visible = true
	interior_scene.visible = false
	current_building = ""

func show_interior(_building_id: String):
	is_in_interior = true
	village_scene.visible = false
	interior_scene.visible = true
	
	# Clear previous interior NPCs
	clear_interior_npcs()
	
	# Add NPCs for this specific building
	var interior_content = interior_scene.get_node("ScrollContainer/InteriorContent")
	for npc_data in npcs:
		if npc_data.building == _building_id:
			create_npc_in_scene(npc_data, interior_content)
	
	# Update interior background (placeholder for now)
	var _interior_bg = interior_scene.get_node("ScrollContainer/InteriorContent/Background")
	# _interior_bg.texture = load(buildings[_building_id].interior_texture)  # Uncomment when textures available

func clear_interior_npcs():
	var interior_content = interior_scene.get_node("ScrollContainer/InteriorContent")
	# Remove all children except the background
	for child in interior_content.get_children():
		if child.name != "Background":
			child.queue_free()

func _on_cancel_pressed():
	if is_in_interior:
		show_village()

func connect_back_button():
	# Connect to the back button via the Portrait controller
	var portrait = get_node("../../")
	if portrait and portrait.has_method("get_back_button"):
		var back_button = portrait.get_back_button()
		if back_button and not back_button.pressed.is_connected(_on_cancel_pressed):
			# Note: This will work in conjunction with the existing back button functionality
			pass

# Allow external access to check if we're in interior
func is_in_building_interior() -> bool:
	return is_in_interior

# Allow external access to handle back navigation
func handle_back_navigation() -> bool:
	if is_in_interior:
		show_village()
		return true  # Handled
	return false  # Not handled, let default back behavior proceed
