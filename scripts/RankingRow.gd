@tool
extends Panel

signal row_clicked(rank: int, player_name: String, faction: int, profession: int, honor: int)

var rank: int = 0
var player_name: String = ""
var faction: int = 0
var profession: int = 0
var honor: int = 0
var is_selected: bool = false

@onready var rank_label: Label = $RowContent/Rank
@onready var name_label: Label = $RowContent/NameContainer/PlayerName
@onready var faction_icon: TextureRect = $RowContent/NameContainer/GuildIcon
@onready var profession_icon: TextureRect = $RowContent/NameContainer/ProfessionIcon
@onready var honor_label: Label = $RowContent/Honor
@onready var click_button: Button = $ClickButton

func _ready():
	if Engine.is_editor_hint():
		return
	
	if click_button:
		click_button.pressed.connect(_on_clicked)
	
	update_display()

func set_data(p_rank: int, p_player_name: String, p_faction: int, p_profession: int, p_honor: int):
	rank = p_rank
	player_name = p_player_name
	faction = p_faction
	profession = p_profession
	honor = p_honor
	update_display()

func update_display():
	if rank_label:
		rank_label.text = str(rank)
	if name_label:
		name_label.text = player_name
	# Faction icon removed - no longer needed
	if profession_icon:
		var icon_path = GameInfo.get_profession_icon(profession)
		if icon_path and ResourceLoader.exists(icon_path):
			profession_icon.texture = load(icon_path)
	if honor_label:
		honor_label.text = str(honor)

func set_selected(selected: bool):
	is_selected = selected
	if is_selected:
		modulate = Color(1.2, 1.2, 1.0)  # Slight yellow tint for selected
	else:
		modulate = Color(1.0, 1.0, 1.0)  # Normal color

func _on_clicked():
	row_clicked.emit(rank, player_name, faction, profession, honor)
