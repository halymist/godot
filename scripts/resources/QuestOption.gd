class_name QuestOption
extends Resource

enum OptionType { DIALOGUE, COMBAT, SKILL_CHECK, CURRENCY_CHECK, END }

@export var option_index: int
@export var option_type: OptionType = OptionType.DIALOGUE
@export var text: String = ""

# For dialogue/end options
@export var slide_target: int = -1

# For combat options
@export var enemy_id: int = -1
@export var on_win_slide: int = -1
@export var on_lose_slide: int = -1

# For skill checks
@export var required_stat: String = ""  # "strength", "stamina", "agility", "luck"
@export var required_amount: int = 0
@export var on_success_slide: int = -1
@export var on_fail_slide: int = -1

# For currency checks
@export var required_silver: int = 0
