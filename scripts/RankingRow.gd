@tool
extends Panel

signal row_clicked(rank: int, player_name: String, rating: int)

var rank: int = 0
var player_name: String = ""
var rating: int = 0

@onready var rank_label: Label = $RowContent/Rank
@onready var name_label: Label = $RowContent/PlayerName
@onready var rating_label: Label = $RowContent/Rating
@onready var click_button: Button = $ClickButton

func _ready():
	if Engine.is_editor_hint():
		return
	
	if click_button:
		click_button.pressed.connect(_on_clicked)
	
	update_display()

func set_data(p_rank: int, p_player_name: String, p_rating: int):
	rank = p_rank
	player_name = p_player_name
	rating = p_rating
	update_display()

func update_display():
	if rank_label:
		rank_label.text = str(rank)
	if name_label:
		name_label.text = player_name
	if rating_label:
		rating_label.text = str(rating)

func _on_clicked():
	row_clicked.emit(rank, player_name, rating)
