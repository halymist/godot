extends AspectRatioContainer

@export var face_rect: TextureRect
@export var hair_rect: TextureRect
@export var eyes_rect: TextureRect
@export var nose_rect: TextureRect
@export var mouth_rect: TextureRect

func _ready():
	print("=== AVATAR _ready() CALLED ===")
	print("Avatar: GameInfo.current_player exists: ", GameInfo.current_player != null)
	
	# Load from GameInfo if player data exists
	if GameInfo.current_player:
		print("Avatar: Loading from GameInfo")
		refresh_avatar(
			GameInfo.current_player.avatar_face,
			GameInfo.current_player.avatar_hair,
			GameInfo.current_player.avatar_eyes,
			GameInfo.current_player.avatar_nose,
			GameInfo.current_player.avatar_mouth
		)
	else:
		# Fallback to default cosmetic IDs
		print("Avatar: No player data, using defaults")
		refresh_avatar(1, 10, 20, 30, 40)

func refresh_avatar(face_id: int, hair_id: int, eyes_id: int, nose_id: int = 30, mouth_id: int = 40):
	"""Load textures from cosmetics database using IDs"""
	print("Avatar: Loading cosmetic IDs - Face: ", face_id, " Hair: ", hair_id, " Eyes: ", eyes_id, " Nose: ", nose_id, " Mouth: ", mouth_id)
	
	if not GameInfo.cosmetics_db:
		print("Avatar ERROR: Cosmetics database not loaded!")
		return
	
	# Load face
	var face_cosmetic = GameInfo.cosmetics_db.get_cosmetic_by_id(face_id)
	if face_cosmetic and face_cosmetic.texture:
		face_rect.texture = face_cosmetic.texture
		print("Avatar: Loaded face cosmetic ID ", face_id)
	else:
		print("Avatar: Failed to load face cosmetic ID ", face_id)
	
	# Load hair
	var hair_cosmetic = GameInfo.cosmetics_db.get_cosmetic_by_id(hair_id)
	if hair_cosmetic and hair_cosmetic.texture:
		hair_rect.texture = hair_cosmetic.texture
		print("Avatar: Loaded hair cosmetic ID ", hair_id)
	else:
		print("Avatar: Failed to load hair cosmetic ID ", hair_id)
	
	# Load eyes
	var eyes_cosmetic = GameInfo.cosmetics_db.get_cosmetic_by_id(eyes_id)
	if eyes_cosmetic and eyes_cosmetic.texture:
		eyes_rect.texture = eyes_cosmetic.texture
		print("Avatar: Loaded eyes cosmetic ID ", eyes_id)
	else:
		print("Avatar: Failed to load eyes cosmetic ID ", eyes_id)
	
	# Load nose
	var nose_cosmetic = GameInfo.cosmetics_db.get_cosmetic_by_id(nose_id)
	if nose_cosmetic and nose_cosmetic.texture:
		nose_rect.texture = nose_cosmetic.texture
		print("Avatar: Loaded nose cosmetic ID ", nose_id)
	else:
		print("Avatar: Failed to load nose cosmetic ID ", nose_id)
	
	# Load mouth
	var mouth_cosmetic = GameInfo.cosmetics_db.get_cosmetic_by_id(mouth_id)
	if mouth_cosmetic and mouth_cosmetic.texture:
		mouth_rect.texture = mouth_cosmetic.texture
		print("Avatar: Loaded mouth cosmetic ID ", mouth_id)
	else:
		print("Avatar: Failed to load mouth cosmetic ID ", mouth_id)
