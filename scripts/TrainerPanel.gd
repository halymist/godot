@tool
extends "res://scripts/UtilityPanel.gd"

# Training costs
const TALENT_POINT_COST = 100
const STAT_COST = 5

# Stat labels
@onready var talent_points_label = $TrainingPanel/Content/StatsContainer/TalentPointsRow/StatInfo/Label
@onready var strength_label = $TrainingPanel/Content/StatsContainer/StrengthRow/StatInfo/Label
@onready var stamina_label = $TrainingPanel/Content/StatsContainer/StaminaRow/StatInfo/Label
@onready var agility_label = $TrainingPanel/Content/StatsContainer/AgilityRow/StatInfo/Label
@onready var luck_label = $TrainingPanel/Content/StatsContainer/LuckRow/StatInfo/Label

# Plus buttons
@onready var talent_points_button = $TrainingPanel/Content/StatsContainer/TalentPointsRow/StatInfo/PlusButton
@onready var strength_button = $TrainingPanel/Content/StatsContainer/StrengthRow/StatInfo/PlusButton
@onready var stamina_button = $TrainingPanel/Content/StatsContainer/StaminaRow/StatInfo/PlusButton
@onready var agility_button = $TrainingPanel/Content/StatsContainer/AgilityRow/StatInfo/PlusButton
@onready var luck_button = $TrainingPanel/Content/StatsContainer/LuckRow/StatInfo/PlusButton

func _ready():
	if Engine.is_editor_hint():
		return
	
	# Connect button signals
	talent_points_button.pressed.connect(_on_talent_points_plus_pressed)
	strength_button.pressed.connect(_on_strength_plus_pressed)
	stamina_button.pressed.connect(_on_stamina_plus_pressed)
	agility_button.pressed.connect(_on_agility_plus_pressed)
	luck_button.pressed.connect(_on_luck_plus_pressed)
	
	# Update stats display when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect to gold changes to update button states
	GameInfo.gold_changed.connect(_on_gold_changed)

func _on_visibility_changed():
	if visible and not Engine.is_editor_hint():
		update_stats_display()
		update_button_states()

func _on_gold_changed():
	if visible and not Engine.is_editor_hint():
		update_button_states()

func update_stats_display():
	if not GameInfo.current_player:
		return
	
	talent_points_label.text = "Talent Points: " + str(GameInfo.current_player.talent_points)
	strength_label.text = "Strength: " + str(GameInfo.current_player.strength)
	stamina_label.text = "Stamina: " + str(GameInfo.current_player.stamina)
	agility_label.text = "Agility: " + str(GameInfo.current_player.agility)
	luck_label.text = "Luck: " + str(GameInfo.current_player.luck)

func update_button_states():
	if not GameInfo.current_player:
		return
	
	var gold = GameInfo.current_player.gold
	
	# Enable/disable buttons based on gold availability
	talent_points_button.disabled = gold < TALENT_POINT_COST
	strength_button.disabled = gold < STAT_COST
	stamina_button.disabled = gold < STAT_COST
	agility_button.disabled = gold < STAT_COST
	luck_button.disabled = gold < STAT_COST

# Training functions
func _on_talent_points_plus_pressed():
	if GameInfo.current_player.gold >= TALENT_POINT_COST:
		GameInfo.current_player.gold -= TALENT_POINT_COST
		GameInfo.current_player.talent_points += 1
		GameInfo.gold_changed.emit()
		GameInfo.stats_changed.emit(GameInfo.current_player.get_player_stats())
		update_stats_display()
		print("Trained Talent Points - cost: ", TALENT_POINT_COST, " gold")

func _on_strength_plus_pressed():
	if GameInfo.current_player.gold >= STAT_COST:
		GameInfo.current_player.gold -= STAT_COST
		GameInfo.current_player.strength += 1
		GameInfo.gold_changed.emit()
		GameInfo.stats_changed.emit(GameInfo.current_player.get_player_stats())
		update_stats_display()
		print("Trained Strength - cost: ", STAT_COST, " gold")

func _on_stamina_plus_pressed():
	if GameInfo.current_player.gold >= STAT_COST:
		GameInfo.current_player.gold -= STAT_COST
		GameInfo.current_player.stamina += 1
		GameInfo.gold_changed.emit()
		GameInfo.stats_changed.emit(GameInfo.current_player.get_player_stats())
		update_stats_display()
		print("Trained Stamina - cost: ", STAT_COST, " gold")

func _on_agility_plus_pressed():
	if GameInfo.current_player.gold >= STAT_COST:
		GameInfo.current_player.gold -= STAT_COST
		GameInfo.current_player.agility += 1
		GameInfo.gold_changed.emit()
		GameInfo.stats_changed.emit(GameInfo.current_player.get_player_stats())
		update_stats_display()
		print("Trained Agility - cost: ", STAT_COST, " gold")

func _on_luck_plus_pressed():
	if GameInfo.current_player.gold >= STAT_COST:
		GameInfo.current_player.gold -= STAT_COST
		GameInfo.current_player.luck += 1
		GameInfo.gold_changed.emit()
		GameInfo.stats_changed.emit(GameInfo.current_player.get_player_stats())
		update_stats_display()
		print("Trained Luck - cost: ", STAT_COST, " gold")
