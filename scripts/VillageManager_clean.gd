extends Panel

@export var village_scene: Control
@export var interior_scene: Control

var current_building: String = ""
var is_in_interior: bool = false

# Building data
var buildings = {
	"blacksmith": {
		"name": "Blacksmith",
		"interior_texture": "res://assets/images/interiors/blacksmith.png"
	},
	"tavern": {
		"name": "Tavern", 
		"interior_texture": "res://assets/images/interiors/tavern.png"
	},
	"shop": {
		"name": "General Store",
		"interior_texture": "res://assets/images/interiors/shop.png"
	}
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

func connect_building_buttons():
	# Connect the building buttons that are in the scene
	var village_content = village_scene.get_node("ScrollContainer/VillageContent")
	
	if village_content.has_node("Blacksmith"):
		village_content.get_node("Blacksmith").pressed.connect(_on_building_clicked.bind("blacksmith"))
	if village_content.has_node("Tavern"):
		village_content.get_node("Tavern").pressed.connect(_on_building_clicked.bind("tavern"))
	if village_content.has_node("Shop"):
		village_content.get_node("Shop").pressed.connect(_on_building_clicked.bind("shop"))

func _on_building_clicked(building_id: String):
	current_building = building_id
	show_interior(building_id)
	print("Entered building: ", buildings[building_id].name)

func show_village():
	is_in_interior = false
	village_scene.visible = true
	interior_scene.visible = false
	current_building = ""

func show_interior(_building_id: String):
	is_in_interior = true
	village_scene.visible = false
	interior_scene.visible = true
	print("Inside: ", buildings[_building_id].name)

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
