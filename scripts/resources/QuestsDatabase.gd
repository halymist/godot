class_name QuestsDatabase
extends Resource

@export var quests: Array[QuestData] = []

func get_quest_by_id(quest_id: int) -> QuestData:
	for quest in quests:
		if quest.quest_id == quest_id:
			return quest
	return null

func get_slide_by_id(quest_id: int, slide_id: int) -> QuestState:
	var quest = get_quest_by_id(quest_id)
	if quest:
		for slide in quest.slides:
			if slide.slide_id == slide_id:
				return slide
	return null
