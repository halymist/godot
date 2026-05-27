class_name ExpeditionData
extends Resource

@export var expedition_id: int = 0
@export var settlement_id: int = 0
@export var map_asset_id: int = 0
@export var version: int = 0
@export var nodes: Array = []
@export var edges: Array = []

var map_texture: Texture2D = null

func get_map_texture() -> Texture2D:
	if not map_texture and map_asset_id > 0:
		map_texture = DataManager.load_asset_texture("expedition-maps", map_asset_id)
	return map_texture

func get_node(node_id: int) -> Resource:
	for node in nodes:
		if node.node_id == node_id:
			return node
	return null

func get_start_nodes() -> Array:
	var start_nodes: Array = []
	for node in nodes:
		if node.is_start:
			start_nodes.append(node)
	return start_nodes

func get_neighbor_node_ids(node_id: int) -> Array[int]:
	var neighbor_ids: Array[int] = []
	for edge in edges:
		if edge.connects(node_id):
			var neighbor_id = edge.other(node_id)
			if neighbor_id > 0 and neighbor_id not in neighbor_ids:
				neighbor_ids.append(neighbor_id)
	return neighbor_ids

func get_completed_node_ids_from_quest_log(quest_log: Array) -> Array[int]:
	var completed_ids: Array[int] = []
	var completed_quests: Dictionary = {}
	for entry in quest_log:
		if entry is Dictionary and entry.get("finished", false):
			completed_quests[int(entry.get("quest_id", 0))] = true

	for node in nodes:
		if completed_quests.has(node.quest_id):
			completed_ids.append(node.node_id)
	return completed_ids

func get_available_node_ids(quest_log: Array) -> Array[int]:
	var available_ids: Array[int] = []
	var completed_ids = get_completed_node_ids_from_quest_log(quest_log)

	for node in get_start_nodes():
		if node.node_id not in available_ids:
			available_ids.append(node.node_id)

	for completed_id in completed_ids:
		if completed_id not in available_ids:
			available_ids.append(completed_id)
		for neighbor_id in get_neighbor_node_ids(completed_id):
			if neighbor_id not in available_ids:
				available_ids.append(neighbor_id)

	return available_ids
