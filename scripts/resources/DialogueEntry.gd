extends Resource
class_name DialogueEntry

@export var questID: int
@export var stage: int  # 0 = quest to be accepted, else ending slide
@export var isQuest: bool  # true = offering a quest
@export var dialogue: String
