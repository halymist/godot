class_name QuestSlide
extends Resource

@export var slide_id: int = 0
@export var asset_id: int = 0  # For background/character art
@export_multiline var text: String = ""
@export var options: Array[QuestOption] = []
@export var reward: QuestReward = null
