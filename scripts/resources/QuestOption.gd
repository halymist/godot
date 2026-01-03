class_name QuestOption
extends Resource

enum RequirementType {
	NONE,
	# Combat
	COMBAT,
	# Stats
	STRENGTH,
	STAMINA,
	AGILITY,
	LUCK,
	ARMOR,
	# Currency
	SILVER,
	# Factions
	ORDER,
	GUILD,
	COMPANIONS,
	# Effects (1-20)
	EFFECT_1, EFFECT_2, EFFECT_3, EFFECT_4, EFFECT_5,
	EFFECT_6, EFFECT_7, EFFECT_8, EFFECT_9, EFFECT_10,
	EFFECT_11, EFFECT_12, EFFECT_13, EFFECT_14, EFFECT_15,
	EFFECT_16, EFFECT_17, EFFECT_18, EFFECT_19, EFFECT_20
}

@export var option_index: int
@export var text: String = ""

# Slide navigation (slide_target for normal/win, on_lose_slide for failure)
@export var slide_target: int = -1  # Default/win slide
@export var on_lose_slide: int = -1  # Failure slide (for combat/checks)

# Unified requirement system
@export var required_type: RequirementType = RequirementType.NONE
@export var required_amount: int = 0
