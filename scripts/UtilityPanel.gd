@tool
extends Panel

@export var village1_texture: Texture
@export var village2_texture: Texture
@export var village3_texture: Texture
@export var village4_texture: Texture
@export var village5_texture: Texture

func _ready():
	if not Engine.is_editor_hint():
		var location = GameInfo.current_player.location if GameInfo.current_player else 1
		set_location_texture(location)
		
		# Connect wrapper button to hide itself when clicked
		var wrapper = get_parent()
		if wrapper and wrapper is Button:
			wrapper.pressed.connect(_on_wrapper_clicked)

func _on_wrapper_clicked():
	# Hide the wrapper button when clicked
	var wrapper = get_parent()
	if wrapper:
		wrapper.visible = false

func _process(_delta):
	_update_layout()

func _update_layout():
	var background_container = get_node_or_null("UtilityBackground")
	if not background_container:
		background_container = get_node_or_null("VendorBackground")
	
	var items_panel = get_node_or_null("UtilityPanel")
	
	var bag = get_node_or_null("Bag")
	
	if not background_container or not items_panel:
		return
	
	# Get parent (wrapper button) size
	var parent = get_parent()
	if not parent:
		return
	
	var parent_width = parent.size.x
	var parent_height = parent.size.y
	
	# Define max width threshold - when we should start constraining
	var max_absolute_width = 500.0  # Adjust this value as needed
	
	var panel_width = parent_width
	
	# Only apply aspect ratio constraint if we exceed the max width
	if parent_width > max_absolute_width:
		var constrained_width = parent_height * (2.2 / 3.0)
		panel_width = min(parent_width, constrained_width)
	
	var panel_height = parent_height
	
	# Update panel size and position (left-aligned)
	size = Vector2(panel_width, panel_height)
	position = Vector2(0, 0)
	
	# Background: full panel width, height adjusted for 0.75 aspect ratio (width:height = 3:4)
	var bg_height = panel_width / 1.5
	background_container.size = Vector2(panel_width, bg_height)
	background_container.position = Vector2(0, 0)
	
	if bag:
		# Bag: position at bottom, centered horizontally within panel
		var bag_x = (panel_width - bag.size.x) / 2.0
		bag.position = Vector2(bag_x, panel_height - bag.size.y)
		
		# Items panel: gets remaining space between background and bag
		var items_height = panel_height - (bg_height + bag.size.y)
		items_panel.size = Vector2(panel_width, items_height)
		items_panel.position = Vector2(0, bg_height)
	else:
		# No bag: items panel gets remaining space from background to bottom
		var items_height = panel_height - bg_height
		items_panel.size = Vector2(panel_width, items_height)
		items_panel.position = Vector2(0, bg_height)

func set_location_texture(location: int):
	var background_texture = get_node_or_null("UtilityBackground/Background")
	if not background_texture or not background_texture is TextureRect:
		return
	
	# Assign the texture based on the location
	var texture: Texture = null
	match location:
		1:
			texture = village1_texture
		2:
			texture = village2_texture
		3:
			texture = village3_texture
		4:
			texture = village4_texture
		5:
			texture = village5_texture
	
	if texture:
		background_texture.texture = texture
