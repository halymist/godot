extends Resource
class_name ItemResource

# Static item data that lives on the client
@export var id: int = 0
@export var item_name: String = ""
@export var type: String = ""
@export var subtype: String = ""
@export var armor: int = 0
@export var strength: int = 0
@export var stamina: int = 0
@export var agility: int = 0
@export var luck: int = 0
@export var damage_min: int = 0
@export var damage_max: int = 0
@export var effect_id: int = 0  # References EffectResource by ID (0 if no effect)
@export var effect_factor: int = 0  # Strength/magnitude of the effect
@export var duration: int = 0  # Duration in days for consumables (0 = permanent/not applicable)
@export var quality: int = 0
@export var price: int = 0
@export var tempered: int = 0  # Tempering level (0 = not tempered, 1+ = tempered)
@export var icon: Texture2D = null
