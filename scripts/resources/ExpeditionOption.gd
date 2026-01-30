class_name ExpeditionOption
extends Resource

# Matches server JSON: option_id, option_text, stat_type, stat_required, effect_id, effect_amount, enemy_id

@export var option_id: int = 0
@export var option_text: String = ""
@export var stat_type: String = ""  # "strength", "stamina", "agility", "luck", or empty
@export var stat_required: int = 0
@export var effect_id: int = 0
@export var effect_amount: float = 0.0
@export var enemy_id: int = 0
