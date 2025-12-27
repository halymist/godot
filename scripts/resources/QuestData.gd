class_name QuestData
extends Resource

@export var quest_id: int = 0
@export var quest_name: String = ""
@export var travel_time: int = 0  # minutes
@export var travel_text: String = ""
@export var slides: Array[QuestSlide] = []
