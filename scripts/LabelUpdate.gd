extends Control

@export var gold_label: Label
@export var currency_label: Label
@export var player_name_label: Label
@export var strength_label: Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
@export var armor_label: Label

func _ready():
	print("LabelUpdate ready!")
	GameInfo.gold_changed.connect(_on_gold_changed)
	GameInfo.currency_changed.connect(_on_currency_changed)
	GameInfo.stats_changed.connect(_on_stats_changed)
	GameInfo.bag_slots_changed.connect(_on_bag_slots_changed)

	_on_gold_changed(GameInfo.player_gold)
	_on_currency_changed(GameInfo.player_currency)
	_on_stats_changed(GameInfo.get_player_stats())

# Called when GameInfo curent player is updated
func _on_gold_changed(new_gold: int):
	print("Gold changed to: ", new_gold)
	gold_label.text = "Gold: " + str(new_gold)

func _on_currency_changed(new_currency: int):
	currency_label.text = "Currency: " + str(new_currency)

func _on_stats_changed(_stats: Dictionary):
	print("Stats changed: ", _stats)
	var total_stats = GameInfo.get_total_stats()
	player_name_label.text = str(total_stats.name)
	strength_label.text = "STRENGTH: " + str(total_stats.strength)
	stamina_label.text = "STAMINA: " + str(total_stats.stamina)
	agility_label.text = "AGILITY: " + str(total_stats.agility)
	luck_label.text = "LUCK: " + str(total_stats.luck)
	armor_label.text = "ARMOR: " + str(total_stats.armor)

func _on_bag_slots_changed():
	print("Bag slots changed - updating stats display")
	var total_stats = GameInfo.get_total_stats()
	player_name_label.text = str(total_stats.name)
	strength_label.text = "STRENGTH: " + str(total_stats.strength)
	stamina_label.text = "STAMINA: " + str(total_stats.stamina)
	agility_label.text = "AGILITY: " + str(total_stats.agility)
	luck_label.text = "LUCK: " + str(total_stats.luck)
	armor_label.text = "ARMOR: " + str(total_stats.armor)
