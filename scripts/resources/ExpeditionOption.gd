class_name ExpeditionOption
extends Resource

# Requirement types for selecting options
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

# Note: next_slide is NOT stored here - server decides it dynamically
# Note: rewards are on slides, not options
