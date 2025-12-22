@tool
extends "res://scripts/ConstrainedPanel.gd"

@export var village1_texture: Texture
@export var village2_texture: Texture
@export var village3_texture: Texture
@export var village4_texture: Texture
@export var village5_texture: Texture

func _ready():
	if not Engine.is_editor_hint():
		var location = GameInfo.current_player.location if GameInfo.current_player else 1
		set_location_texture(location)

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
