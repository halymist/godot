extends Resource
class_name NpcResource

@export var id: int
@export var name: String
@export var quest_dialogues: Array[QuestDialogueEntry] = []
@export var normal_dialogues: Array[NormalDialogueEntry] = []
@export var asset: Texture2D
@export var portrait: Texture2D
@export var spot: int  # Spot number for placement
@export var building_id: int  # 0 = outside (village), else building ID

func get_quest_dialogue(quest_id: int) -> QuestDialogueEntry:
	for dialogue in quest_dialogues:
		if dialogue.quest_id == quest_id:
			return dialogue
	return null

func get_normal_dialogue_for_options(clicked_options: Array[int]) -> NormalDialogueEntry:
	for dialogue in normal_dialogues:
		if dialogue.required_options.size() == 0:
			continue
		var all_present = true
		for req in dialogue.required_options:
			if not clicked_options.has(req):
				all_present = false
				break
		if all_present:
			return dialogue
	return null
