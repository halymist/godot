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
	print("LabelUpdate: Connecting to GameInfo signals...")
	GameInfo.gold_changed.connect(_on_gold_changed)
	GameInfo.currency_changed.connect(_on_currency_changed)
	GameInfo.stats_changed.connect(_on_stats_changed)
	GameInfo.on_player_data_loaded.connect(_on_player_data_loaded)
	
	print("LabelUpdate: Connected to GameInfo signals successfully")
	
	# Initialize UI with current values since signals may have already been emitted
	_update_ui_with_current_data()

# Update UI with current GameInfo data (for initial setup)
func _update_ui_with_current_data():
	print("LabelUpdate: Initializing UI with current GameInfo data...")
	
	# Update gold and currency
	_on_gold_changed(GameInfo.player_gold)
	_on_currency_changed(GameInfo.player_currency)
	
	# Update stats if player data exists
	if GameInfo.current_player.has("name"):
		_on_stats_changed(GameInfo.get_player_stats())

# Called when gold changes
func _on_gold_changed(new_gold: int):
	print("LabelUpdate: _on_gold_changed called with: ", new_gold)
	if gold_label:
		gold_label.text = "Gold: " + str(new_gold)
		print("LabelUpdate: Gold label updated to: ", gold_label.text)
	else:
		print("LabelUpdate: Warning - gold_label is null!")

# Called when currency changes
func _on_currency_changed(new_currency: int):
	print("LabelUpdate: _on_currency_changed called with: ", new_currency)
	if currency_label:
		currency_label.text = "Currency: " + str(new_currency)
		print("LabelUpdate: Currency label updated to: ", currency_label.text)
	else:
		print("LabelUpdate: Warning - currency_label is null!")

# Called when stats change
func _on_stats_changed(stats: Dictionary):
	print("LabelUpdate: _on_stats_changed called with: ", stats)
	if player_name_label:
		player_name_label.text = "Player: " + str(stats.name)
		print("LabelUpdate: Name label updated to: ", player_name_label.text)
	else:
		print("LabelUpdate: Warning - player_name_label is null!")
		
	if strength_label:
		strength_label.text = "STR: " + str(stats.strength)
	else:
		print("LabelUpdate: Warning - strength_label is null!")
		
	if stamina_label:
		stamina_label.text = "CON: " + str(stats.stamina)
	else:
		print("LabelUpdate: Warning - stamina_label is null!")
		
	if agility_label:
		agility_label.text = "DEX: " + str(stats.agility)
	else:
		print("LabelUpdate: Warning - agility_label is null!")
		
	if luck_label:
		luck_label.text = "LUK: " + str(stats.luck)
	else:
		print("LabelUpdate: Warning - luck_label is null!")

# Called when player data is fully loaded
func _on_player_data_loaded():
	print("LabelUpdate: Player data loaded - UI ready")

# Example function to test the signal system
func _on_test_button_pressed():
	GameInfo.add_gold(100)
	GameInfo.add_currency(10)
