extends Resource
class_name ItemDatabase

@export var items: Array[ItemResource] = []

func get_item_by_id(item_id: int) -> ItemResource:
	for item in items:
		if item.id == item_id:
			return item
	return null
