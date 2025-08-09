extends Panel

@export var village_scene: Control
@export var interior_scene: Control
@export var building_prefab: PackedScene

var current_building: String = ""
var is_in_interior: bool = false

# Building data with different interior sizes and texture paths
var buildings = {
	"blacksmith": {"name": "Blacksmith", "interior_width": 1000, "texture_path": "res://textures/buildings/blacksmith.png"},
	"tavern": {"name": "Tavern", "interior_width": 1500, "texture_path": "res://textures/buildings/tavern.png"},
	"shop": {"name": "General Store", "interior_width": 1200, "texture_path": "res://textures/buildings/shop.png"},
	"inn": {"name": "Inn", "interior_width": 1800, "texture_path": "res://textures/buildings/inn.png"},
	"market": {"name": "Market", "interior_width": 2000, "texture_path": "res://textures/buildings/market.png"},
	"bank": {"name": "Bank", "interior_width": 800, "texture_path": "res://textures/buildings/bank.png"},
	"temple": {"name": "Temple", "interior_width": 1600, "texture_path": "res://textures/buildings/temple.png"},
	"guild": {"name": "Guild Hall", "interior_width": 1400, "texture_path": "res://textures/buildings/guild.png"},
	"stables": {"name": "Stables", "interior_width": 1300, "texture_path": "res://textures/buildings/stables.png"},
	"library": {"name": "Library", "interior_width": 2200, "texture_path": "res://textures/buildings/library.png"}
}

func _ready():
	# Get references to child nodes
	village_scene = get_node("VillageView")
	interior_scene = get_node("InteriorView")
	
	# Set up initial state
	show_village()
	
	# Create building instances from prefabs
	create_building_prefabs()
	
	# Connect to the main back button
	call_deferred("connect_back_button")

func create_building_prefabs():
	if not building_prefab:
		print("Warning: Building prefab not assigned!")
		return
		
	var village_content = village_scene.get_node("ScrollContainer/VillageContent")
	
	# Clear existing buildings first
	for child in village_content.get_children():
		if child is Button and child.name != "VillageBackground":
			child.queue_free()
	
	# Create buildings from prefab
	var building_keys = buildings.keys()
	for i in range(building_keys.size()):
		var building_id = building_keys[i]
		var building_data = buildings[building_id]
		
		# Instance the prefab
		var building_instance = building_prefab.instantiate()
		
		# Position the building
		building_instance.position = Vector2(100 + i * 150, 250)
		building_instance.size = Vector2(100, 80)
		
		# Load texture if it exists
		var texture = null
		if ResourceLoader.exists(building_data.texture_path):
			texture = load(building_data.texture_path)
		
		# Set building data
		building_instance.set_building_data(
			building_id,
			building_data.name,
			texture,
			building_data.interior_width
		)
		
		# Connect the signal
		building_instance.building_clicked.connect(_on_building_clicked)
		
		# Add to village
		village_content.add_child(building_instance)

func _on_building_clicked(building_id: String):
	current_building = building_id
	show_interior(building_id)
	print("Entered building: ", buildings[building_id].name)

func show_village():
	is_in_interior = false
	village_scene.visible = true
	interior_scene.visible = false
	current_building = ""

func show_interior(building_id: String):
	is_in_interior = true
	village_scene.visible = false
	interior_scene.visible = true
	
	# Set interior size based on building type
	var interior_content = interior_scene.get_node("ScrollContainer/InteriorContent")
	var interior_width = buildings[building_id].interior_width
	interior_content.custom_minimum_size = Vector2(interior_width, 600)
	
	print("Inside: ", buildings[building_id].name, " (", interior_width, "px wide)")

func connect_back_button():
	# Connect to back button functionality
	var toggle_panel = get_node("../../../TogglePanel")
	if toggle_panel and toggle_panel.has_method("set_village_manager"):
		toggle_panel.set_village_manager(self)

func go_back():
	if is_in_interior:
		show_village()
	else:
		# Let the TogglePanel handle going back to previous screen
		pass
