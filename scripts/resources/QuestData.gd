class_name QuestData
extends Resource

@export var quest_id: int = 0
@export var quest_name: String = ""
@export var background_texture: Texture2D = null
@export var travel_text: String = ""

# Flat quest structure
@export_multiline var initial_text: String = ""  # Starting text
@export var initial_reward: QuestReward = null  # Reward given at start (if any)
@export var options: Array[QuestOption] = []  # ALL options for this quest
@export var initially_visible_options: Array[int] = []  # Which options show at start
