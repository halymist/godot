extends AspectRatioContainer

@export var face_textures: Array[Texture2D] = []
@export var hair_textures: Array[Texture2D] = []
@export var eyes_textures: Array[Texture2D] = []

@onready var face_rect: TextureRect = $AvatarControl/Face
@onready var hair_rect: TextureRect = $AvatarControl/Hair
@onready var eyes_rect: TextureRect = $AvatarControl/Eyes

func _ready():
	print("=== AVATAR _ready() CALLED ===")
	print("Avatar: GameInfo.current_player exists: ", GameInfo.current_player != null)
	
	# Connect to avatar changed signal
	GameInfo.avatar_changed.connect(_on_avatar_changed)
	
	# Load from GameInfo if player data exists
	if GameInfo.current_player:
		print("Avatar: Loading from GameInfo with hair ID: ", GameInfo.current_player.avatar_hair)
		set_avatar_from_ids(
			GameInfo.current_player.avatar_face,
			GameInfo.current_player.avatar_hair,
			GameInfo.current_player.avatar_eyes
		)
	else:
		# Fallback to default
		print("Avatar: No player data, using defaults")
		set_avatar_from_ids(1, 1, 1)

func _on_avatar_changed(face_id: int, hair_id: int, eyes_id: int):
	print("Avatar: Received avatar_changed signal - Face:", face_id, " Hair:", hair_id, " Eyes:", eyes_id)
	set_avatar_from_ids(face_id, hair_id, eyes_id)

func set_avatar_from_ids(face_id: int, hair_id: int, eyes_id: int):
	"""Load textures from IDs (1-based indexing)"""
	print("Avatar: Loading IDs - Face: ", face_id, " Hair: ", hair_id, " Eyes: ", eyes_id)
	var face_index = face_id - 1
	var hair_index = hair_id - 1
	var eyes_index = eyes_id - 1
	
	if face_index >= 0 and face_index < face_textures.size() and face_textures[face_index]:
		face_rect.texture = face_textures[face_index]
		print("Avatar: Loaded face texture at index ", face_index)
	else:
		print("Avatar: Failed to load face - index: ", face_index, " array size: ", face_textures.size())
	
	if hair_index >= 0 and hair_index < hair_textures.size() and hair_textures[hair_index]:
		hair_rect.texture = hair_textures[hair_index]
		print("Avatar: Loaded hair texture at index ", hair_index)
	else:
		print("Avatar: Failed to load hair - index: ", hair_index, " array size: ", hair_textures.size())
	
	if eyes_index >= 0 and eyes_index < eyes_textures.size() and eyes_textures[eyes_index]:
		eyes_rect.texture = eyes_textures[eyes_index]
		print("Avatar: Loaded eyes texture at index ", eyes_index)
	else:
		print("Avatar: Failed to load eyes - index: ", eyes_index, " array size: ", eyes_textures.size())
