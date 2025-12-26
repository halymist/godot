extends Control

@export var player_name_label: Label
@export var rank_label: Label
@export var guild_label: Label
@export var profession_label: Label
@export var strength_label: Label
@export var strength_aprox: Label
@export var stamina_label: Label
@export var stamina_aprox: Label
@export var agility_label: Label
@export var agility_aprox: Label
@export var luck_label: Label
@export var luck_aprox: Label
@export var armor_label: Label

# Effect value labels (On Self column)
@export var effect_strength_value: Label  # ID 1
@export var effect_stamina_value: Label   # ID 2
@export var effect_agility_value: Label   # ID 3
@export var effect_luck_value: Label      # ID 4
@export var effect_damage_value: Label    # ID 5
@export var effect_health_value: Label    # ID 6
@export var effect_crit_chance_value: Label  # ID 7
@export var effect_dodge_value: Label     # ID 8
@export var effect_damage_reduction_value: Label  # ID 9
@export var effect_initiative_value: Label  # ID 10
@export var effect_stun_value: Label      # ID 11
@export var effect_counter_attack_value: Label  # ID 12
@export var effect_attack_twice_value: Label  # ID 13
@export var effect_bleed_value: Label     # ID 14
@export var effect_lifesteal_value: Label  # ID 15
@export var effect_heal_value: Label      # ID 16
@export var effect_survive_value: Label   # ID 17
@export var effect_healing_boost_value: Label  # ID 18
@export var effect_crit_damage_value: Label  # ID 19
@export var effect_counter_damage_value: Label  # ID 20

func _ready():
	stats_changed(GameInfo.get_player_stats())

# Called when GameInfo current player is updated
func stats_changed(_stats: Dictionary):
	var total_stats = GameInfo.get_total_stats()
	player_name_label.text = str(total_stats.name)
	rank_label.text = GameInfo.current_player.get_rank_name() + " (" + str(GameInfo.current_player.rank) + ")"
	guild_label.text = GameInfo.current_player.get_guild_name()
	profession_label.text = GameInfo.current_player.get_profession_name()
	strength_label.text = str(int(total_stats.strength))
	strength_aprox.text = "(100)"
	stamina_label.text = str(int(total_stats.stamina))
	stamina_aprox.text = "(100)"
	agility_label.text = str(int(total_stats.agility))
	agility_aprox.text = "(100)"
	luck_label.text = str(int(total_stats.luck))
	luck_aprox.text = "(100)"
	armor_label.text = str(int(total_stats.armor))
