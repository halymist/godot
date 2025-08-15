extends TextureRect
class_name Building

@export var building_id: String = ""
@export var building_name: String = ""
@export var interior_texture: Texture2D
@export var interior_background: TextureRect  # Direct reference to interior background
@export var interior_content: Control  # Direct reference to interior content
@export var npc_prefab: PackedScene  # NPC prefab for spawning

@onready var click_button: Button = $ClickButton

signal building_clicked(building: Building)

var spawned_npcs: Array = []

func _ready():
	# Connect the button press signal
	click_button.button_up.connect(_on_button_pressed)
	
	# Load NPC prefab if not assigned
	if not npc_prefab:
		npc_prefab = preload("res://Scenes/NPC.tscn")

func _on_button_pressed():
	building_clicked.emit(self)

func show_interior():
	# Apply interior texture and adjust size to match texture aspect ratio
	if interior_background and interior_texture and interior_content:
		interior_background.texture = interior_texture
		
		# Get the texture size
		var texture_size = interior_texture.get_size()
		
		# Get the actual height of the interior content area
		var content_height = interior_content.size.y
		if content_height <= 0:
			# Fallback to parent container height
			var scroll_container = interior_content.get_parent()
			if scroll_container:
				content_height = scroll_container.size.y
		
		print("Interior content height: ", content_height)
		
		# Calculate width based on texture aspect ratio and actual content height
		var aspect_ratio = texture_size.x / texture_size.y
		var target_width = content_height * aspect_ratio
		
		# Set the custom minimum size to match the aspect ratio
		interior_content.custom_minimum_size = Vector2(target_width, content_height)
		
		print("Set interior size to ", target_width, "x", content_height, " (aspect ratio: ", aspect_ratio, ")")
		print("Original texture size: ", texture_size)
		
		print("Applied interior texture and sized content")
	else:
		print("Warning: Missing interior references - background:", interior_background != null, " texture:", interior_texture != null, " content:", interior_content != null)

func spawn_building_npcs():
	# Clear existing NPCs
	clear_spawned_npcs()
	
	if not npc_prefab or not interior_content:
		print("Cannot spawn NPCs - missing prefab or interior content")
		return
	
	# Get NPCs for this building from GameInfo
	var npcs_data = GameInfo.npcs
	var building_int_id = int(building_id)  # Convert string ID to int for comparison
	
	for npc_data in npcs_data:
		var npc_building_id = npc_data.get("building", 0)
		
		# Only spawn NPCs that belong to this building
		if npc_building_id == building_int_id:
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
