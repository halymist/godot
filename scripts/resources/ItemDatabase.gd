extends Resource
class_name ItemDatabase

@export var items: Array[ItemResource] = []

func get_item_by_id(item_id: int) -> ItemResource:
	# If ID > 1000, it's an encoded elixir - return base elixir item (ID 1000)
	if item_id > 1000:
		for item in items:
			if item.id == 1000:
				return item
		return null
	
	# Regular item lookup
	for item in items:
		if item.id == item_id:
			return item
	return null
