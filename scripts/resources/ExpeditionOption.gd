class_name ExpeditionOption
extends Resource

# Same reward types as QuestOption for consistency
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

# Same requirement types as QuestOption for consistency
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
	COMPANIONS
}

@export var option_id: int = 0
@export var text: String = ""

# Requirement to select this option (optional)
@export var required_type: RequirementType = RequirementType.NONE
@export var required_amount: int = 0

# Reward given when selecting this option (optional)
@export var reward_type: RewardType = RewardType.NONE
@export var reward_amount: int = 0

# Note: next_slide is NOT stored here - server decides it dynamically
