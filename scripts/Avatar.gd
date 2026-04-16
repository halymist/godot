extends AspectRatioContainer

# Layer order matches cosmetics designer (z-order: first = back, last = front)
const LAYER_ORDER = ["face", "ears", "nose", "mouth", "eyes", "brows", "beard", "special", "hair"]

# Static TextureRect nodes in the scene (set via @export so visible in editor with fallback textures)
@export var face_rect: TextureRect
@export var ears_rect: TextureRect
@export var nose_rect: TextureRect
@export var mouth_rect: TextureRect
@export var eyes_rect: TextureRect
@export var brows_rect: TextureRect
@export var beard_rect: TextureRect
@export var special_rect: TextureRect
@export var hair_rect: TextureRect

# Cosmetic IDs keyed by type
var equipped: Dictionary = {}  # type -> cosmetic_id

func _get_rect(layer_type: String) -> TextureRect:
	match layer_type:
		"face": return face_rect
		"ears": return ears_rect
		"nose": return nose_rect
		"mouth": return mouth_rect
		"eyes": return eyes_rect
		"brows": return brows_rect
		"beard": return beard_rect
		"special": return special_rect
		"hair": return hair_rect
		_: return null

func _ready():
	if GameInfo.cosmetics_db and GameInfo.current_player:
		set_avatar_from_player(GameInfo.current_player)
	# Otherwise the fallback textures from the scene are already visible

func set_avatar_from_player(player):
	set_avatar_ids({
		"face": player.avatar_face,
		"hair": player.avatar_hair,
		"eyes": player.avatar_eyes,
		"nose": player.avatar_nose,
		"mouth": player.avatar_mouth,
		"brows": player.avatar_brows,
		"ears": player.avatar_ears,
		"special": player.avatar_special
	})

func set_avatar_ids(ids: Dictionary):
	equipped = ids
	refresh_avatar()

func refresh_avatar(face_id: int = -1, hair_id: int = -1, eyes_id: int = -1, nose_id: int = -1, mouth_id: int = -1):
	if face_id >= 0:
		equipped["face"] = face_id
	if hair_id >= 0:
		equipped["hair"] = hair_id
	if eyes_id >= 0:
		equipped["eyes"] = eyes_id
	if nose_id >= 0:
		equipped["nose"] = nose_id
	if mouth_id >= 0:
		equipped["mouth"] = mouth_id
	
	# If cosmetics DB isn't loaded yet, keep fallback textures as-is
	if not GameInfo.cosmetics_db:
		return
	
	for layer_type in LAYER_ORDER:
		var rect = _get_rect(layer_type)
		if not rect:
			continue
		
		if not equipped.has(layer_type) or equipped[layer_type] <= 0:
			# No cosmetic equipped for this layer — hide only if no fallback texture
			if not rect.texture:
				rect.visible = false
			continue
		
		var cosmetic = GameInfo.cosmetics_db.get_cosmetic_by_id(equipped[layer_type])
		if not cosmetic:
			# ID doesn't exist in DB — keep whatever texture/fallback is there
			continue
		
		# Update texture from cosmetic data (keep fallback if cosmetic texture is null)
		if cosmetic.texture:
			rect.texture = cosmetic.texture
		rect.visible = true
		
		# Apply positioning from cosmetic data (face always fills full space)
		if layer_type != "face":
			var sc = cosmetic.scale / 100.0
			var ox = cosmetic.offset_x / 100.0
			var oy = cosmetic.offset_y / 100.0
			
			var half_w = sc / 2.0
			var half_h = sc / 2.0
			var cx = 0.5 + ox
			var cy = 0.5 + oy
			
			rect.anchor_left = cx - half_w
			rect.anchor_top = cy - half_h
			rect.anchor_right = cx + half_w
			rect.anchor_bottom = cy + half_h
			# Clear pixel offsets so anchors alone control position
			rect.offset_left = 0
			rect.offset_top = 0
			rect.offset_right = 0
			rect.offset_bottom = 0
			rect.offset_left = 0
			rect.offset_top = 0
			rect.offset_right = 0
			rect.offset_bottom = 0
