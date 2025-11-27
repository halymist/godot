extends Resource
class_name PerkResource

# Static perk data that lives on the client
@export var id: int = 0
@export var perk_name: String = ""
@export var effect1_id: int = 0  # First effect reference
@export var factor1: float = 0.0  # First effect magnitude
@export var effect2_id: int = 0  # Second effect reference (0 if no second effect)
@export var factor2: float = 0.0  # Second effect magnitude
@export var icon: Texture2D = null
