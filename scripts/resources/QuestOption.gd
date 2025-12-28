class_name QuestOption
extends Resource

enum Faction { NONE, ORDER, GUILD, COMPANIONS }
enum Stat { NONE, STRENGTH, STAMINA, AGILITY, LUCK, ARMOR }

@export var option_index: int
@export var text: String = ""

# For dialogue/end options
@export var slide_target: int = -1

# For combat options
@export var enemy_id: int = -1
@export var on_win_slide: int = -1
@export var on_lose_slide: int = -1

# For skill checks
@export var required_stat: Stat = Stat.NONE
@export var required_amount: int = 0

# For currency checks
@export var required_silver: int = 0

# For faction checks
@export var required_faction: Faction = Faction.NONE
