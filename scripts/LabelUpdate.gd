extends Control

@export var player_name_label: Label
@export var rank_label: Label
@export var guild_label: Label
@export var guild_icon: TextureRect
@export var profession_label: Label
@export var profession_icon: TextureRect
@export var talent_points_label: Label
@export var strength_label: Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
@export var armor_label: Label

func _ready():
	stats_changed(GameInfo.get_player_stats())

# Called when GameInfo current player is updated
func stats_changed(_stats: Dictionary):
	print("Stats changed: ", _stats)
	var total_stats = GameInfo.get_total_stats()
	player_name_label.text = str(total_stats.name)
	rank_label.text = GameInfo.current_player.get_rank_name() + " (" + str(GameInfo.current_player.rank) + ")"
	guild_label.text = GameInfo.current_player.get_guild_name()
	if guild_icon:
		var icon_path = GameInfo.get_guild_icon(GameInfo.current_player.guild)
		if icon_path and ResourceLoader.exists(icon_path):
			guild_icon.texture = load(icon_path)
	profession_label.text = GameInfo.current_player.get_profession_name()
	if profession_icon:
		var icon_path = GameInfo.get_profession_icon(GameInfo.current_player.profession)
		print("Loading profession icon: ", icon_path)
		if icon_path and ResourceLoader.exists(icon_path):
			profession_icon.texture = load(icon_path)
			print("Profession icon loaded successfully")
		else:
			print("Profession icon file not found: ", icon_path)
	if talent_points_label:
		talent_points_label.text = "TALENT POINTS: " + str(GameInfo.current_player.talent_points)
	strength_label.text = "STRENGTH: " + str(int(total_stats.strength))
	stamina_label.text = "STAMINA: " + str(int(total_stats.stamina))
	agility_label.text = "AGILITY: " + str(int(total_stats.agility))
	luck_label.text = "LUCK: " + str(int(total_stats.luck))
	armor_label.text = "ARMOR: " + str(int(total_stats.armor))
