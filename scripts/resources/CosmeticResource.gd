extends Resource
class_name CosmeticResource

@export var id: int = 0
@export var cosmetic_name: String = ""
@export var category: String = ""  # "face", "hair", "eyes", "nose", "mouth", "beard", "brows", "ears", "special"
@export var texture: Texture2D = null
@export var cost: int = 0  # Mushroom cost (0 = free/default)
@export var offset_x: float = 0.0  # Percentage offset X (ignored for face)
@export var offset_y: float = 0.0  # Percentage offset Y (ignored for face)
@export var scale: float = 100.0  # Scale percentage (ignored for face, 100 = normal)
