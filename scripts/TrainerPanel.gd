@tool
extends Control

# Stat labels
@onready var talent_points_label = $TrainingPanel/Content/StatsContainer/TalentPointsRow/StatInfo/Label
@onready var strength_label = $TrainingPanel/Content/StatsContainer/StrengthRow/StatInfo/Label
@onready var constitution_label = $TrainingPanel/Content/StatsContainer/ConstitutionRow/StatInfo/Label
@onready var dexterity_label = $TrainingPanel/Content/StatsContainer/DexterityRow/StatInfo/Label
@onready var luck_label = $TrainingPanel/Content/StatsContainer/LuckRow/StatInfo/Label

# Plus buttons
@onready var talent_points_button = $TrainingPanel/Content/StatsContainer/TalentPointsRow/StatInfo/PlusButton
@onready var strength_button = $TrainingPanel/Content/StatsContainer/StrengthRow/StatInfo/PlusButton
@onready var constitution_button = $TrainingPanel/Content/StatsContainer/ConstitutionRow/StatInfo/PlusButton
@onready var dexterity_button = $TrainingPanel/Content/StatsContainer/DexterityRow/StatInfo/PlusButton
@onready var luck_button = $TrainingPanel/Content/StatsContainer/LuckRow/StatInfo/PlusButton

func _ready():
	if Engine.is_editor_hint():
		return
	
	# Connect button signals (functionality to be added later)
	talent_points_button.pressed.connect(_on_talent_points_plus_pressed)
	strength_button.pressed.connect(_on_strength_plus_pressed)
	constitution_button.pressed.connect(_on_constitution_plus_pressed)
	dexterity_button.pressed.connect(_on_dexterity_plus_pressed)
	luck_button.pressed.connect(_on_luck_plus_pressed)
	
	# Update stats display when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible and not Engine.is_editor_hint():
		update_stats_display()

func update_stats_display():
	if not GameInfo.current_player:
		return
	
	talent_points_label.text = "Talent Points: " + str(GameInfo.current_player.talent_points)
	strength_label.text = "Strength: " + str(GameInfo.current_player.strength)
	constitution_label.text = "Constitution: " + str(GameInfo.current_player.constitution)
	dexterity_label.text = "Dexterity: " + str(GameInfo.current_player.dexterity)
	luck_label.text = "Luck: " + str(GameInfo.current_player.luck)

# Placeholder functions for stat training (to be implemented)
func _on_talent_points_plus_pressed():
	print("Train Talent Points clicked - costs 100 gold")

func _on_strength_plus_pressed():
	print("Train Strength clicked - costs 5 gold")

func _on_constitution_plus_pressed():
	print("Train Constitution clicked - costs 5 gold")

func _on_dexterity_plus_pressed():
	print("Train Dexterity clicked - costs 5 gold")

func _on_luck_plus_pressed():
	print("Train Luck clicked - costs 5 gold")
