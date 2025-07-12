extends Control

# UI Labels - assign these in the inspector
@export var gold_label: Label
@export var currency_label: Label
@export var player_name_label: Label
@export var strength_label: Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label

func _ready():
	# Connect to GameInfo signals directly (AutoLoad)
	GameInfo.gold_changed.connect(_on_gold_changed)
	GameInfo.currency_changed.connect(_on_currency_changed)
	GameInfo.stats_changed.connect(_on_stats_changed)
	GameInfo.on_player_data_loaded.connect(_on_player_data_loaded)

# Called when gold changes
func _on_gold_changed(new_gold: int):
	if gold_label:
		gold_label.text = "Gold: " + str(new_gold)

# Called when currency changes
func _on_currency_changed(new_currency: int):
	if currency_label:
		currency_label.text = "Currency: " + str(new_currency)

# Called when stats change
func _on_stats_changed(stats: Dictionary):
	if player_name_label:
		player_name_label.text = "Player: " + str(stats.name)
	if strength_label:
		strength_label.text = "STR: " + str(stats.strength)
	if stamina_label:
		stamina_label.text = "CON: " + str(stats.stamina)
	if agility_label:
		agility_label.text = "DEX: " + str(stats.agility)
	if luck_label:
		luck_label.text = "LUK: " + str(stats.luck)

# Called when player data is fully loaded
func _on_player_data_loaded():
	pass  # Can add any post-load UI setup here if needed

# Example function to test the signal system
func _on_test_button_pressed():
	GameInfo.add_gold(100)
	GameInfo.add_currency(10)
