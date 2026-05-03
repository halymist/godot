extends Resource
class_name PerkDatabase

# Array of all perks in the game
@export var perks: Array[PerkResource] = []

# Lookup function to get perk by ID
func get_perk_by_id(perk_id: int) -> PerkResource:
	for perk in perks:
		if perk.id == perk_id:
			return perk
	return null
