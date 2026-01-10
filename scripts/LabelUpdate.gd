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

func _ready():
	# Connect to character changed signal
	GameInfo.character_changed.connect(_on_character_changed)
	stats_changed(GameInfo.get_player_stats())

func _on_character_changed():
	stats_changed(GameInfo.get_player_stats())

# Called when GameInfo current player is updated
func stats_changed(_stats: Dictionary):
	var total_stats = GameInfo.get_total_stats()
	
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
