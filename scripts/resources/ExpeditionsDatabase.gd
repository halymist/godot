class_name ExpeditionsDatabase
extends Resource

@export var expeditions: Array[Resource] = []  # Array of ExpeditionData

func get_expedition(expedition_id: int) -> Resource:
	"""Get expedition by ID"""
	for expedition in expeditions:
		if expedition.id == expedition_id:
			return expedition
	return null
