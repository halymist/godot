extends Resource
class_name EffectResource

# Static effect data that lives on the client
@export var id: int = 0
@export var name: String = ""
@export var description: String = ""
@export var slot: String = ""  # Equipment slot (Head, Chest, Weapon, etc.)
@export var icon: Texture2D = null
