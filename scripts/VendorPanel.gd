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
		set_vendor_location(location)

func _process(_delta):
	_update_layout()

func _update_layout():
	var vendor_background = get_node_or_null("VendorBackground")
	var items_panel = get_node_or_null("ItemsPanel")
	var player_bag_panel = get_node_or_null("PlayerBagPanel")
	
	if not vendor_background or not items_panel or not player_bag_panel:
		return
	
	# Get available size
	var panel_width = size.x
	var panel_height = size.y
	
	# Vendor background: full width, height adjusted for 0.75 aspect ratio (width:height = 3:4)
	var bg_height = panel_width / 1.5
	vendor_background.size = Vector2(panel_width, bg_height)
	vendor_background.position = Vector2(0, 0)
	
	# Remaining height after vendor background
	var remaining_height = panel_height - bg_height
	
	# Items panel: 80% of remaining height
	var items_height = remaining_height * 0.8
	items_panel.size = Vector2(panel_width, items_height)
	items_panel.position = Vector2(0, bg_height)
	
	# Player bag panel: 20% of remaining height
	var bag_height = remaining_height * 0.2
	player_bag_panel.size = Vector2(panel_width, bag_height)
	player_bag_panel.position = Vector2(0, bg_height + items_height)

func set_vendor_location(location: int):
	var background_texture = get_node_or_null("VendorBackground/Background")
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
