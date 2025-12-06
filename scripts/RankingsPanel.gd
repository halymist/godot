@tool
extends Panel

@export var rankings_table: ScrollContainer
@export var player_card: Panel
@export var search_input: LineEdit
@export var ranking_row_scene: PackedScene

@onready var table_content: VBoxContainer
@onready var player_name_label: Label
@onready var player_rank_label: Label
@onready var player_rating_label: Label
@onready var fight_button: Button

var selected_row = null

func _ready():
	if Engine.is_editor_hint():
		return
	if rankings_table:
		table_content = rankings_table.get_node("VBoxContainer")
	
	if player_card:
		var card_content = player_card.get_node("CardContent")
		var player_info = card_content.get_node("PlayerInfo")
		player_name_label = player_info.get_node("PlayerName")
		player_rank_label = player_info.get_node("PlayerRank")
		player_rating_label = player_info.get_node("PlayerRating")
		
		var actions = card_content.get_node("FightButtonContainer")
		fight_button = actions.get_node("FightButton")
		if fight_button:
			fight_button.pressed.connect(_on_fight_pressed)
	
	if search_input:
		search_input.text_changed.connect(_on_search_changed)
	
	# Adjust layout when visible
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		populate_rankings()

func populate_rankings():
	if not table_content:
		return
	
	# Clear existing rows
	for child in table_content.get_children():
		child.queue_free()
	
	# TODO: Populate with actual ranking data
	# For now, create placeholder rows
	for i in range(20):
		var row = create_ranking_row(i + 1, "Player" + str(i + 1), 1000 - (i * 50))
		if row:
			table_content.add_child(row)

func create_ranking_row(rank: int, p_player_name: String, p_rating: int):
	if not ranking_row_scene:
		print("Warning: ranking_row_scene not set in RankingsPanel")
		return null
	
	var row = ranking_row_scene.instantiate()
	row.set_data(rank, p_player_name, p_rating)
	row.row_clicked.connect(_on_row_clicked)
	return row

func _on_row_clicked(rank: int, player_name: String, rating: int):
	print("Clicked on player: ", player_name, " Rank: ", rank, " Rating: ", rating)
	
	# Deselect previous row
	if selected_row and is_instance_valid(selected_row):
		selected_row.set_selected(false)
	
	# Find and select new row
	if table_content:
		for child in table_content.get_children():
			if child.rank == rank:
				child.set_selected(true)
				selected_row = child
				break
	
	update_player_card(rank, player_name, rating)

func update_player_card(rank: int, player_name: String, rating: int):
	if player_name_label:
		player_name_label.text = player_name
	if player_rank_label:
		player_rank_label.text = "Rank: #" + str(rank)
	if player_rating_label:
		player_rating_label.text = "Rating: " + str(rating)

func _on_fight_pressed():
	print("Fight button pressed!")
	# TODO: Implement fight challenge

func _on_search_changed(new_text: String):
	# TODO: Filter rankings based on search text
	print("Search: ", new_text)
