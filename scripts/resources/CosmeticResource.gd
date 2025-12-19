extends Resource
class_name CosmeticResource

@export var id: int = 0
@export var cosmetic_name: String = ""
@export var category: String = ""  # "Face", "Hair", "Eyes", "Nose", "Mouth"
@export var texture: Texture2D = null
@export var cost: int = 0  # Mushroom cost (0 = free/default)
