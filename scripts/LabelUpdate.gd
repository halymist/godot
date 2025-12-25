extends Control

@export var player_name_label: Label
@export var rank_label: Label
@export var guild_label: Label
@export var guild_icon: TextureRect
@export var profession_label: Label
@export var profession_icon: TextureRect
@export var talent_points_label: Label
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
	# Load profession icon once on ready
	if profession_icon:
		var icon_path = GameInfo.get_profession_icon(GameInfo.current_player.profession)
		if icon_path and ResourceLoader.exists(icon_path):
			profession_icon.texture = load(icon_path)
	
	# Load guild icon once on ready
	if guild_icon:
		var icon_path = GameInfo.get_guild_icon(GameInfo.current_player.guild)
		if icon_path and ResourceLoader.exists(icon_path):
			guild_icon.texture = load(icon_path)
	
	stats_changed(GameInfo.get_player_stats())

# Called when GameInfo current player is updated
func stats_changed(_stats: Dictionary):
	var total_stats = GameInfo.get_total_stats()
	player_name_label.text = str(total_stats.name)
	rank_label.text = GameInfo.current_player.get_rank_name() + " (" + str(GameInfo.current_player.rank) + ")"
	guild_label.text = GameInfo.current_player.get_guild_name()
	profession_label.text = GameInfo.current_player.get_profession_name()
	if talent_points_label:
		talent_points_label.text = "TALENT POINTS: " + str(GameInfo.current_player.talent_points)
	strength_label.text = "STRENGTH: " + str(int(total_stats.strength))
	stamina_label.text = "STAMINA: " + str(int(total_stats.stamina))
	agility_label.text = "AGILITY: " + str(int(total_stats.agility))
	luck_label.text = "LUCK: " + str(int(total_stats.luck))
	armor_label.text = "ARMOR: " + str(int(total_stats.armor))
