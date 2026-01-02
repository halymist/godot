extends Control

@export var player_name_label: Label
@export var rank_label: Label
@export var faction_label: Label
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
@export var talents_label: Label
@export var health_bar: TextureProgressBar
@export var damage_spread_label: Label

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
	var total_effects = GameInfo.get_total_effects()
	
	player_name_label.text = str(total_stats.name)
	rank_label.text = GameInfo.current_player.get_rank_name() + " (" + str(GameInfo.current_player.rank) + ")"
	faction_label.text = GameInfo.current_player.get_faction_name()
	profession_label.text = GameInfo.current_player.get_profession_name()
	
	# Display already-calculated stats from GameInfo
	strength_label.text = str(total_stats.strength)
	strength_aprox.text = "(100)"
	stamina_label.text = str(total_stats.stamina)
	stamina_aprox.text = "(100)"
	agility_label.text = str(total_stats.agility)
	agility_aprox.text = "(100)"
	luck_label.text = str(total_stats.luck)
	luck_aprox.text = "(100)"
	armor_label.text = str(total_stats.armor)

	var spent_points = 0
	for talent in GameInfo.current_player.talents:
		spent_points += talent.points
		
	talents_label.text = "Talent points: %d/%d" % [spent_points, GameInfo.current_player.talent_points]
	
	# Calculate and display health bar (stamina * 10)
	if health_bar:
		var max_health = total_stats.stamina * 10
		health_bar.max_value = max_health
		health_bar.value = max_health
		if health_bar.has_node("HealthLabel"):
			health_bar.get_node("HealthLabel").text = str(max_health)
	
	# Calculate and display damage spread (strength * weapon damage range)
	if damage_spread_label:
		var weapon_item = null
		# Find equipped weapon in slots 0-8
		for item in GameInfo.current_player.bag_slots:
			if item != null and item.bag_slot_id >= 0 and item.bag_slot_id <= 8:
				if item.type == "Weapon":
					weapon_item = item
					break
		
		if weapon_item != null:
			var min_damage = total_stats.strength * weapon_item.damage_min
			var max_damage = total_stats.strength * weapon_item.damage_max
			damage_spread_label.text = str(min_damage) + " - " + str(max_damage)
		else:
			damage_spread_label.text = "0 - 0"
	
	# Calculate and display effect values (without % suffix)
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
