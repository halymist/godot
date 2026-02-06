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

# New server format fields
@export var option_id: int = 0
@export var option_text: String = ""  # Button text
@export var node_text: String = ""  # Text shown when this option is reached

# Legacy fields (for backwards compatibility)
@export var option_index: int
@export var text: String = ""

# Response text shown when option is clicked
@export_multiline var response_text: String = ""  # Text shown when clicked (replaces current text)
@export_multiline var on_lose_response_text: String = ""  # Text shown when combat is lost

# Visibility control - which options to show/hide after clicking this
@export var shows_option_ids: Array[int] = []  # Show these options after clicking (win)
@export var hides_option_ids: Array[int] = []  # Hide these options after clicking (win)
@export var on_lose_shows_option_ids: Array[int] = []  # Show these options on combat loss
@export var on_lose_hides_option_ids: Array[int] = []  # Hide these options on combat loss

# Requirements from server (new format)
@export var stat_type: int = 0  # Stat required (1=str, 2=sta, 3=agi, 4=luck)
@export var stat_required: int = 0  # Amount needed
@export var effect_id: int = 0  # Effect required
@export var effect_amount: int = 0  # Effect amount needed
@export var enemy_id: int = 0  # Enemy to fight (if combat required)
@export var is_start: bool = false  # Is this a starting option
@export var requirements: Array[int] = []  # Option IDs that must be clicked first

# Quest completion
@export var ends_quest: bool = false  # If true, quest completes after this option

# Unified requirement system (legacy)
@export var required_type: RequirementType = RequirementType.NONE
@export var required_amount: int = 0

# Reward system (new server format)
@export var reward_stat_type: int = 0  # Stat to reward
@export var reward_stat_amount: int = 0  # Amount of stat
@export var reward_talent: int = 0  # Talent points to reward
@export var reward_item: int = 0  # Item ID to reward
@export var reward_perk: int = 0  # Perk ID to reward
@export var reward_blessing: int = 0  # Blessing ID to reward
@export var reward_potion: int = 0  # Potion ID to reward

# Reward system (legacy)
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

@export var reward_type: RewardType = RewardType.NONE
@export var reward_amount: int = 0
