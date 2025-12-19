extends Resource
class_name CosmeticDatabase

@export var cosmetics: Array[CosmeticResource] = []

func get_cosmetic_by_id(cosmetic_id: int) -> CosmeticResource:
	for cosmetic in cosmetics:
		if cosmetic.id == cosmetic_id:
			return cosmetic
	return null

func get_cosmetics_by_category(category: String) -> Array[CosmeticResource]:
	var result: Array[CosmeticResource] = []
	for cosmetic in cosmetics:
		if cosmetic.category == category:
			result.append(cosmetic)
	return result
