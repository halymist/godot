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

func _process(_delta):
	_update_layout()

func _update_layout():
	var background_container = get_node_or_null("UtilityBackground")
	var items_panel = get_node_or_null("ItemsPanel")
	var bag = get_node_or_null("Bag")
	
	if not background_container or not items_panel or not bag:
		return
	
	# Get available size
	var panel_width = size.x
	var panel_height = size.y
	
	# Background: full width, height adjusted for 0.75 aspect ratio (width:height = 3:4)
	var bg_height = panel_width / 1.5
	background_container.size = Vector2(panel_width, bg_height)
	background_container.position = Vector2(0, 0)
	
	# Bag: position at bottom, uses its natural size
	bag.position = Vector2(0, panel_height - bag.size.y)
	
	# Items panel: gets remaining space between background and bag
	var items_height = panel_height - (bg_height + bag.size.y)
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
