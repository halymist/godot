extends Panel

@export var village_scene: Control
@export var interior_scene: Control

var current_building: String = ""
var is_in_interior: bool = false

# Building data - you can expand this later
var buildings = {
	"blacksmith": {
		"name": "Blacksmith",
		"position": Vector2(150, 200),
		"interior_texture": "res://assets/images/interiors/blacksmith.png"
	},
	"tavern": {
		"name": "Tavern", 
		"position": Vector2(350, 180),
		"interior_texture": "res://assets/images/interiors/tavern.png"
	},
	"shop": {
		"name": "General Store",
		"position": Vector2(250, 250),
		"interior_texture": "res://assets/images/interiors/shop.png"
	}
}

func _ready():
	# Get references to child nodes
	village_scene = get_node("VillageView")
	interior_scene = get_node("InteriorView")
	
	# Set up initial state
	show_village()
	
	# Create buildings
	create_buildings()
	
	# Connect to the main back button via GameInfo or by finding the Portrait controller
	call_deferred("connect_back_button")

func create_buildings():
	var village_content = village_scene.get_node("ScrollContainer/VillageContent")
	
	for building_id in buildings:
		var building_data = buildings[building_id]
		
		# Create building button
		var building_button = Button.new()
		building_button.name = building_id
		building_button.text = building_data.name
		building_button.size = Vector2(100, 80)
		building_button.position = building_data.position
		
		# Style the building button
		building_button.flat = false
		building_button.add_theme_color_override("font_color", Color.WHITE)
		building_button.add_theme_font_size_override("font_size", 16)
		
		# Connect button signal
		building_button.pressed.connect(_on_building_clicked.bind(building_id))
		
		village_content.add_child(building_button)

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
	
	# Update interior background (placeholder for now)
	var _interior_bg = interior_scene.get_node("ScrollContainer/InteriorContent/Background")
	# _interior_bg.texture = load(buildings[_building_id].interior_texture)  # Uncomment when textures available

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
