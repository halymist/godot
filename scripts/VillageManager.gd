extends Panel

@export var village_scene: Control
@export var interior_scene: Control

var current_building: String = ""
var is_in_interior: bool = false

func _ready():
	# Get references to child nodes
	village_scene = get_node("VillageView")
	interior_scene = get_node("InteriorView")
	
	# Set up initial state
	show_village()
	
	# Connect to existing buildings in the scene
	connect_existing_buildings()
	
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

func _on_building_clicked(building_id: String, interior_background: TextureRect, interior_texture: Texture2D):
	current_building = building_id
	show_interior(interior_background, interior_texture)
	print("Entered building: ", building_id)

func show_village():
	is_in_interior = false
	village_scene.visible = true
	interior_scene.visible = false
	current_building = ""

func show_interior(interior_background: TextureRect = null, interior_texture: Texture2D = null):
	is_in_interior = true
	village_scene.visible = false
	interior_scene.visible = true
	
	# Apply interior texture directly to the referenced background
	if interior_background and interior_texture:
		interior_background.texture = interior_texture
		print("Applied interior texture directly to referenced background")
	elif interior_texture:
		# Fallback: try to find background by path if direct reference not set
		var interior_content = interior_scene.get_node("ScrollContainer/InteriorContent")
		var background = interior_content.get_node_or_null("Background")
		if background and background is TextureRect:
			background.texture = interior_texture
			print("Applied interior texture to background via fallback method")
		else:
			print("Warning: No background found and no direct reference set")
	
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
