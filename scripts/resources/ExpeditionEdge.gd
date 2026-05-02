class_name ExpeditionEdge
extends Resource

@export var edge_id: int = 0
@export var node_a: int = 0
@export var node_b: int = 0
@export var version: int = 0

func connects(node_id: int) -> bool:
	return node_a == node_id or node_b == node_id

func other(node_id: int) -> int:
	if node_a == node_id:
		return node_b
	if node_b == node_id:
		return node_a
	return 0
