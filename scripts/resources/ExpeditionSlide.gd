class_name ExpeditionSlide
extends Resource

# Matches server JSON: slide_id, slide_text, asset_id, effect_id, effect_factor,
# reward_stat_type, reward_stat_amount, reward_talent, reward_item, reward_perk, reward_blessing, reward_potion
# options: array of ExpeditionOption

@export var slide_id: int = 0
@export_multiline var slide_text: String = ""
@export var asset_id: int = 0
@export var effect_id: int = 0
@export var effect_factor: float = 0.0

# Rewards (all optional, from server)
@export var reward_stat_type: int = 0
@export var reward_stat_amount: int = 0
@export var reward_talent: int = 0
@export var reward_item: int = 0
@export var reward_perk: int = 0
@export var reward_blessing: int = 0
@export var reward_potion: int = 0

# Options - use Array (not typed) for reliable .res serialization
@export var options: Array = []

# Runtime only - NOT saved to .res
var texture: Texture2D = null
