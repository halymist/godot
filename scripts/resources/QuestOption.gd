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

# Response text shown when option is clicked
@export_multiline var response_text: String = ""  # Text shown when clicked (replaces current text)

# Visibility control - which options to show/hide after clicking this
@export var shows_option_ids: Array[int] = []  # Show these options after clicking
@export var hides_option_ids: Array[int] = []  # Hide these options after clicking
@export var is_blocking: bool = false  # If true, hides all other options when clicked

# Navigation (0 = stay on current state, >0 = go to state, -1 = end quest)
@export var navigates_to_slide: int = 0  # Which state to navigate to after clicking
@export var on_lose_slide: int = -1  # Failure state (for combat/checks)

# Unified requirement system
@export var required_type: RequirementType = RequirementType.NONE
@export var required_amount: int = 0
