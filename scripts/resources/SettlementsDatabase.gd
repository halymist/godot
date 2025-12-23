extends Resource
class_name SettlementsDatabase

# Array of all settlements/locations in the game
@export var settlements: Array[LocationResource] = []

# Lookup function to get location by ID
func get_location_by_id(location_id: int) -> LocationResource:
	for location in settlements:
		if location.location_id == location_id:
			return location
	return null
