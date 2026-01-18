class_name ExpeditionSlide
extends Resource

const ExpeditionOptionScript = preload("res://scripts/resources/ExpeditionOption.gd")

# Reward types (same as QuestOption for consistency)
enum RewardType {
	NONE,
	SILVER,
	ITEM,
	PERK,
	STRENGTH,
	STAMINA,
	AGILITY,
	LUCK,
	ARMOR,
	MIN_DAMAGE,
	MAX_DAMAGE,
	TALENT_POINT,
	POTION,
	BLESSING
}

@export var slide_id: int = 0
@export_multiline var text: String = ""
@export var texture: Texture2D = null
@export var options: Array[Resource] = []  # Array of ExpeditionOption

# Reward given when reaching this slide
@export var reward_type: RewardType = RewardType.NONE
@export var reward_amount: int = 0
