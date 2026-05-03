class_name QuestState
extends Resource

@export_multiline var text: String = ""
@export var options: Array[QuestOption] = []
@export var initially_visible_options: Array[int] = []  # Option indices visible when entering this state (empty = all visible)
@export var reward: QuestReward = null
