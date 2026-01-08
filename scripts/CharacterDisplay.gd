extends Control
class_name CharacterDisplay

# Button references
@export var talents_button: Button
@export var details_button: Button
@export var avatar_button: Button

# Stats display references (from LabelUpdate.gd)
@export var player_name_label: Label
@export var rank_label: Label
@export var faction_label: Label
@export var strength_label: Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
@export var armor_label: Label
@export var health_bar: TextureProgressBar
@export var damage_spread_label: Label

func _ready():
	# Connect button signals
	talents_button.pressed.connect(_on_talents_pressed)
	details_button.pressed.connect(_on_details_pressed)
	avatar_button.pressed.connect(_on_avatar_pressed)
	
	# Initial stats display
	stats_changed(GameInfo.get_player_stats())

# Called when GameInfo current player is updated
func stats_changed(_stats: Dictionary):
	var total_stats = GameInfo.get_total_stats()
	
	player_name_label.text = str(total_stats.name)
	rank_label.text = GameInfo.current_player.get_rank_name() + " (" + str(GameInfo.current_player.rank) + ")"
	faction_label.text = GameInfo.current_player.get_faction_name()

	
	# Display already-calculated stats from GameInfo
	strength_label.text = str(total_stats.strength)
	stamina_label.text = str(total_stats.stamina)
	agility_label.text = str(total_stats.agility)
	luck_label.text = str(total_stats.luck)
	armor_label.text = str(total_stats.armor)	

	
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

func _on_talents_pressed():
	UIManager.instance.toggle_talents_bookmark()

func _on_details_pressed():
	UIManager.instance.toggle_details_bookmark()

func _on_avatar_pressed():
	UIManager.instance.toggle_avatar_overlay()
