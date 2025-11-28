extends Resource
class_name NpcResource

@export var id: int
@export var name: String
@export var dialogues: Array[DialogueEntry] = []
@export var asset: Texture2D
@export var portrait: Texture2D
@export var spot: int  # Spot number for placement
@export var building_id: int  # 0 = outside (village), else building ID

func get_dialogue(quest_id: int, quest_stage: int) -> DialogueEntry:
	for dialogue_entry in dialogues:
		if dialogue_entry.questID == quest_id and dialogue_entry.stage == quest_stage:
			return dialogue_entry
	return null
