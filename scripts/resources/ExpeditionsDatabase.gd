class_name ExpeditionsDatabase
extends Resource

@export var expeditions: Array = []
@export var version: int = 0

func get_expedition(expedition_id: int) -> ExpeditionData:
	for expedition in expeditions:
		if expedition.expedition_id == expedition_id:
			return expedition
	return null

func get_expedition_for_settlement(settlement_id: int) -> ExpeditionData:
	for expedition in expeditions:
		if expedition.settlement_id == settlement_id:
			return expedition
	return null

func get_node(expedition_id: int, node_id: int) -> Resource:
	var expedition = get_expedition(expedition_id)
	return expedition.get_node(node_id) if expedition else null
