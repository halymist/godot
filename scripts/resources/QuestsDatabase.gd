class_name QuestsDatabase
extends Resource

@export var quests: Array[QuestData] = []

func get_quest_by_id(quest_id: int) -> QuestData:
	for quest in quests:
		if quest.quest_id == quest_id:
			return quest
	return null
