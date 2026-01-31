extends Resource
class_name SettlementsDatabase

# Collection of settlements loaded from server
@export var settlements: Array = []  # Array of Settlement (untyped for reliable .res serialization)
@export var version: int = 0

# Lookup function to get settlement by ID
func get_settlement_by_id(settlement_id: int) -> Settlement:
	for settlement in settlements:
		if settlement.settlement_id == settlement_id:
			return settlement
	return null

# Alias for backwards compatibility
func get_location_by_id(location_id: int) -> Settlement:
	return get_settlement_by_id(location_id)
