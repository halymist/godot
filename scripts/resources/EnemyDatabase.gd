extends Resource
class_name EnemyDatabase

@export var enemies: Array[EnemyResource] = []

func get_enemy_by_id(id: int) -> EnemyResource:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return null
