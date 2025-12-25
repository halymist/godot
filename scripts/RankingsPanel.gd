extends Panel

@export var rankings_table: ScrollContainer
@export var player_card: Panel
@export var search_input: LineEdit
@export var ranking_row_scene: PackedScene
@export var enemy_panel: Control

# Stat nodes from player card
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label

@onready var table_content: VBoxContainer
@onready var player_name_label: Label
@onready var fight_button: Button
@onready var character_button: Button
@onready var avatar_instance: Node

var selected_row = null
var selected_player: GameInfo.GameArenaOpponent = null

func _ready():
	if Engine.is_editor_hint():
		return
	if rankings_table:
		table_content = rankings_table.get_node("VBoxContainer")
	
	if player_card:
		var card_content = player_card.get_node("CardContent")
		var player_info = card_content.get_node("PlayerInfo")
		player_name_label = player_info.get_node("PlayerName")
		
		# Get character button and avatar instance
		var character_container = card_content.get_node("Character")
		if character_container:
			avatar_instance = character_container.get_node("Avatar")
			character_button = character_container.get_node("Button")
			if character_button:
				character_button.pressed.connect(_on_character_button_pressed)
		
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
	
	# Populate with rankings from GameInfo (using indices into enemy_players)
	for index in GameInfo.rankings_indices:
		if index < GameInfo.enemy_players.size():
			var player = GameInfo.enemy_players[index]
			var row = create_ranking_row(player)
			if row:
				table_content.add_child(row)

func create_ranking_row(player: GameInfo.GameArenaOpponent):
	if not ranking_row_scene:
		print("Warning: ranking_row_scene not set in RankingsPanel")
		return null
	
	var row = ranking_row_scene.instantiate()
	row.set_data(player.rank, player.name, player.guild, player.profession, player.honor)
	row.row_clicked.connect(_on_row_clicked)
	return row

func _on_row_clicked(rank: int, player_name: String, guild: int, profession: int, honor: int):
	print("Clicked on player: ", player_name, " Rank: ", rank, " Guild: ", guild, " Profession: ", profession, " Honor: ", honor)
	
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
	if not selected_player:
		return
	
	if player_name_label:
		player_name_label.text = selected_player.name
	
	# Update avatar with player's face, hair, eyes, nose, and mouth
	if avatar_instance and avatar_instance.has_method("set_avatar_from_ids"):
		avatar_instance.set_avatar_from_ids(
			selected_player.avatar_face,
			selected_player.avatar_hair,
			selected_player.avatar_eyes,
			selected_player.avatar_nose,
			selected_player.avatar_mouth
		)
	
	# Get total stats (base + equipment + perks)
	var total_stats = selected_player.get_total_stats()
	
	# Update stat values directly on Label exports
	if strength:
		strength.text = str(total_stats.strength)
	if stamina:
		stamina.text = str(total_stats.stamina)
	if agility:
		agility.text = str(total_stats.agility)
	if luck:
		luck.text = str(total_stats.luck)
	if armor:
		armor.text = str(total_stats.armor)

func _on_fight_pressed():
	print("Fight button pressed!")
	# TODO: Implement fight challenge

func _on_search_changed(new_text: String):
	# TODO: Filter rankings based on search text
	print("Search: ", new_text)

func _on_character_button_pressed():
	if enemy_panel:
		enemy_panel.visible = !enemy_panel.visible
		if enemy_panel.visible:
			GameInfo.set_current_panel(enemy_panel)
