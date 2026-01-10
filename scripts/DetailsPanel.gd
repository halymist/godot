extends Control
class_name DetailsPanel

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

var displayed_character: GameInfo.GamePlayer

# Display effects for a specific character (player or enemy)
func display_effects(character: GameInfo.GamePlayer):
	displayed_character = character
	update_effect_values()

# Update all effect labels based on the displayed character
func update_effect_values():
	if not displayed_character:
		return
	
	var total_effects = displayed_character.get_total_effects()
	
	# Update each effect label (without % suffix)
	if effect_strength_value:
		effect_strength_value.text = "-" if total_effects[1] == 0 else str(int(total_effects[1]))
	if effect_stamina_value:
		effect_stamina_value.text = "-" if total_effects[2] == 0 else str(int(total_effects[2]))
	if effect_agility_value:
		effect_agility_value.text = "-" if total_effects[3] == 0 else str(int(total_effects[3]))
	if effect_luck_value:
		effect_luck_value.text = "-" if total_effects[4] == 0 else str(int(total_effects[4]))
	if effect_damage_value:
		effect_damage_value.text = "-" if total_effects[5] == 0 else str(int(total_effects[5]))
	if effect_health_value:
		effect_health_value.text = "-" if total_effects[6] == 0 else str(int(total_effects[6]))
	if effect_crit_chance_value:
		effect_crit_chance_value.text = "-" if total_effects[7] == 0 else str(int(total_effects[7]))
	if effect_dodge_value:
		effect_dodge_value.text = "-" if total_effects[8] == 0 else str(int(total_effects[8]))
	if effect_damage_reduction_value:
		effect_damage_reduction_value.text = "-" if total_effects[9] == 0 else str(int(total_effects[9]))
	if effect_initiative_value:
		effect_initiative_value.text = "-" if total_effects[10] == 0 else str(int(total_effects[10]))
	if effect_stun_value:
		effect_stun_value.text = "-" if total_effects[11] == 0 else str(int(total_effects[11]))
	if effect_counter_attack_value:
		effect_counter_attack_value.text = "-" if total_effects[12] == 0 else str(int(total_effects[12]))
	if effect_attack_twice_value:
		effect_attack_twice_value.text = "-" if total_effects[13] == 0 else str(int(total_effects[13]))
	if effect_bleed_value:
		effect_bleed_value.text = "-" if total_effects[14] == 0 else str(int(total_effects[14]))
	if effect_lifesteal_value:
		effect_lifesteal_value.text = "-" if total_effects[15] == 0 else str(int(total_effects[15]))
	if effect_heal_value:
		effect_heal_value.text = "-" if total_effects[16] == 0 else str(int(total_effects[16]))
	if effect_survive_value:
		effect_survive_value.text = "-" if total_effects[17] == 0 else str(int(total_effects[17]))
	if effect_healing_boost_value:
		effect_healing_boost_value.text = "-" if total_effects[18] == 0 else str(int(total_effects[18]))
	if effect_crit_damage_value:
		effect_crit_damage_value.text = "-" if total_effects[19] == 0 else str(int(total_effects[19]))
	if effect_counter_damage_value:
		effect_counter_damage_value.text = "-" if total_effects[20] == 0 else str(int(total_effects[20]))
