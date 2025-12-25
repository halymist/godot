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
