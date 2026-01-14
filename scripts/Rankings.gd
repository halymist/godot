extends Panel

# Direct exports for all required nodes
@export var rankings_table: ScrollContainer
@export var table_content: VBoxContainer
@export var player_card: Control
@export var search_input: LineEdit
@export var ranking_row_scene: PackedScene

# Player card components
@export var player_name_label: Label
@export var avatar_instance: Node
@export var character_button: Button
@export var fight_button: Button

# Player card stat labels
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label

var selected_row = null
var selected_player: GameInfo.GamePlayer = null

func _ready():
	character_button.pressed.connect(_on_character_button_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	search_input.text_changed.connect(_on_search_changed)
	
	populate_rankings()
	


func populate_rankings():
	# Clear existing rows
	for child in table_content.get_children():
		child.queue_free()
	
	# Populate with rankings from GameInfo
	for player in GameInfo.enemy_players:
		var row = ranking_row_scene.instantiate()
		row.set_data(player.rank, player.name, player.faction, player.profession, player.honor)
		row.row_clicked.connect(_on_row_clicked)
		table_content.add_child(row)

func _on_row_clicked(rank: int, player_name: String, faction: int, profession: int, honor: int):
	print("Clicked on player: ", player_name, " Rank: ", rank, " Faction: ", faction, " Profession: ", profession, " Honor: ", honor)
	
	# Find the full player object from enemy_players
	selected_player = null
	for player in GameInfo.enemy_players:
		if player.name == player_name:
			selected_player = player
			break
	
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
	
	if selected_player:
		update_player_card()

func update_player_card():
	player_name_label.text = selected_player.name
	
	# Update avatar
	avatar_instance.refresh_avatar(
		selected_player.avatar_face,
		selected_player.avatar_hair,
		selected_player.avatar_eyes,
		selected_player.avatar_nose,
		selected_player.avatar_mouth
	)
	
	# Get total stats and update labels
	var total_stats = selected_player.get_total_stats()
	strength.text = str(total_stats.strength)
	stamina.text = str(total_stats.stamina)
	agility.text = str(total_stats.agility)
	luck.text = str(total_stats.luck)
	armor.text = str(total_stats.armor)

func _on_fight_pressed():
	print("Fight button pressed!")
	# TODO: Implement fight challenge

func _on_search_changed(new_text: String):
	# TODO: Filter rankings based on search text
	print("Search: ", new_text)

func _on_character_button_pressed():
	print("RankingsPanel: Opening enemy panel for: ", selected_player.name)
	UIManager.instance.show_enemy_panel(selected_player.name)
