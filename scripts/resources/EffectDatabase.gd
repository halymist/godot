extends Resource
class_name EffectDatabase

# Array of all effects in the game
@export var effects: Array[EffectResource] = []

# Lookup function to get effect by ID
func get_effect_by_id(effect_id: int) -> EffectResource:
	for effect in effects:
		if effect.id == effect_id:
			return effect
	return null
