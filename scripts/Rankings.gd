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
@export var fight_status_label: Label

# Player card stat labels
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label

var selected_row = null
var selected_player: GameInfo.GamePlayer = null

# Pagination tracking
var loaded_min_rank: int = 1
var loaded_max_rank: int = 100
var is_loading_up: bool = false
var is_loading_down: bool = false
var top_loading_rows: Array[Control] = []
var bottom_loading_rows: Array[Control] = []
const LOADING_ROWS_COUNT: int = 20

func _ready():
	# Always connect buttons and signals
	character_button.pressed.connect(_on_character_button_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	search_input.text_changed.connect(_on_search_changed)
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect scroll detection for pagination
	rankings_table.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	
	if UIManager.instance.game_is_ready:
		print("Rankings: Game already ready, calling setup immediately")
		_setup()
	else:
		print("Rankings: Connecting to game_ready signal")
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	populate_rankings()
	await get_tree().process_frame
	_check_load_more()

func _on_visibility_changed():
	if visible:
		_select_current_player()
		fight_button.visible = false

func _on_scroll_changed(_value: float):
	_check_load_more()

func _check_load_more():
	var visible_rect = rankings_table.get_global_rect()
	
	if top_loading_rows.size() > 0 and not is_loading_up:
		for row in top_loading_rows:
			if is_instance_valid(row):
				var row_rect = row.get_global_rect()
				if row_rect.intersects(visible_rect) and loaded_min_rank > 1:
					is_loading_up = true
					Websocket.load_rankings(1, loaded_min_rank)
					break
	
	if bottom_loading_rows.size() > 0 and not is_loading_down:
		for row in bottom_loading_rows:
			if is_instance_valid(row):
				var row_rect = row.get_global_rect()
				if row_rect.intersects(visible_rect):
					is_loading_down = true
					Websocket.load_rankings(2, loaded_max_rank)
					break

func populate_rankings():
	for child in table_content.get_children():
		child.queue_free()
	
	top_loading_rows.clear()
	bottom_loading_rows.clear()
	
	if GameInfo.rankings_players.size() > 0:
		loaded_min_rank = GameInfo.rankings_players[0].rank
		loaded_max_rank = GameInfo.rankings_players[-1].rank
	
	if loaded_min_rank > 1:
		for i in range(LOADING_ROWS_COUNT):
			var row = _create_loading_row()
			top_loading_rows.append(row)
			table_content.add_child(row)
	
	for player in GameInfo.rankings_players:
		var row = ranking_row_scene.instantiate()
		row.set_data(player.rank, player.name, player.faction, player.honor)
		row.row_clicked.connect(_on_row_clicked)
		row.row_double_clicked.connect(_on_row_double_clicked)
		table_content.add_child(row)
	
	for i in range(LOADING_ROWS_COUNT):
		var row = _create_loading_row()
		bottom_loading_rows.append(row)
		table_content.add_child(row)
	
	is_loading_up = false
	is_loading_down = false

func _create_loading_row() -> Control:
	var row = ranking_row_scene.instantiate()
	row.set_data(0, "Loading...", 0, 0)
	row.modulate = Color(0.5, 0.5, 0.5, 0.7)
	return row

func _clear_loading_rows(rows: Array[Control]):
	for row in rows:
		if is_instance_valid(row):
			row.queue_free()
	rows.clear()

func append_rankings_up(new_players: Array):
	if new_players.size() == 0:
		_clear_loading_rows(top_loading_rows)
		is_loading_up = false
		return
	
	var insert_index = top_loading_rows.size()
	
	for player in new_players:
		var row = ranking_row_scene.instantiate()
		row.set_data(player.rank, player.name, player.faction, player.honor)
		row.row_clicked.connect(_on_row_clicked)
		row.row_double_clicked.connect(_on_row_double_clicked)
		table_content.add_child(row)
		table_content.move_child(row, insert_index)
		insert_index += 1
	
	loaded_min_rank = new_players[0].rank
	
	if loaded_min_rank <= 1:
		_clear_loading_rows(top_loading_rows)
	
	is_loading_up = false

func append_rankings_down(new_players: Array):
	if new_players.size() == 0:
		_clear_loading_rows(bottom_loading_rows)
		is_loading_down = false
		return
	
	var bottom_index = table_content.get_child_count() - bottom_loading_rows.size()
	
	for player in new_players:
		var row = ranking_row_scene.instantiate()
		row.set_data(player.rank, player.name, player.faction, player.honor)
		row.row_clicked.connect(_on_row_clicked)
		row.row_double_clicked.connect(_on_row_double_clicked)
		table_content.add_child(row)
		table_content.move_child(row, bottom_index)
		bottom_index += 1
	
	loaded_max_rank = new_players[-1].rank
	is_loading_down = false

func _on_row_clicked(rank: int, player_name: String, _faction: int, _honor: int):
	selected_player = null
	for player in GameInfo.rankings_players:
		if player.name == player_name:
			selected_player = player
			break
	
	if selected_row and is_instance_valid(selected_row):
		selected_row.set_selected(false)
	
	for child in table_content.get_children():
		if child in top_loading_rows or child in bottom_loading_rows:
			continue
		if child.rank == rank:
			child.set_selected(true)
			selected_row = child
			break
	
	if selected_player:
		_update_fight_button_state()
		update_player_card()

func _update_fight_button_state():
	"""Update fight button visibility and status based on player state"""
	# Don't show fight button for self
	if selected_player == GameInfo.current_player:
		fight_button.visible = false
		if fight_status_label:
			fight_status_label.visible = false
		return
	
	# Check if player can fight
	var can_fight := true
	var status_text := ""
	
	if UIManager.instance:
		if UIManager.instance.is_traveling():
			can_fight = false
			status_text = "Can't fight while traveling"
		elif UIManager.instance.is_on_active_quest() or UIManager.instance.is_on_expedition():
			can_fight = false
			status_text = "Can't fight while on quest"
	
	fight_button.visible = true
	fight_button.disabled = not can_fight
	if fight_status_label:
		fight_status_label.text = status_text
		fight_status_label.visible = not can_fight

func update_player_card():
	player_name_label.text = selected_player.name
	
	avatar_instance.refresh_avatar(
		selected_player.avatar_face,
		selected_player.avatar_hair,
		selected_player.avatar_eyes,
		selected_player.avatar_nose,
		selected_player.avatar_mouth
	)
	
	var total_stats = selected_player.get_total_stats()
	strength.text = str(total_stats.strength)
	stamina.text = str(total_stats.stamina)
	agility.text = str(total_stats.agility)
	luck.text = str(total_stats.luck)
	armor.text = str(total_stats.armor)

func _select_current_player():
	if selected_row and is_instance_valid(selected_row):
		selected_row.set_selected(false)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	for child in table_content.get_children():
		if child in top_loading_rows or child in bottom_loading_rows:
			continue
		if child.rank == GameInfo.current_player.rank:
			child.set_selected(true)
			selected_row = child
			selected_player = GameInfo.current_player
			update_player_card()
			_scroll_to_center(child)
			break

func _scroll_to_center(control: Control):
	var scroll_height = rankings_table.size.y
	var control_pos = control.position.y
	var control_height = control.size.y
	var target_scroll = control_pos - (scroll_height / 2) + (control_height / 2)
	target_scroll = max(0, target_scroll)
	rankings_table.scroll_vertical = int(target_scroll)

func _on_fight_pressed():
	if selected_player:
		# Send fight request to server - combat result will come via WebSocket response
		Websocket.fight_player(selected_player.character_id)
		# TODO: Handle combat response in Websocket._handle_message() and show combat panel

func _on_search_changed(_new_text: String):
	pass

func _on_row_double_clicked(rank: int, player_name: String, faction: int, honor: int):
	_on_row_clicked(rank, player_name, faction, honor)
	_on_character_button_pressed()

func _on_character_button_pressed():
	if not selected_player:
		return
	
	if selected_player == GameInfo.current_player:
		UIManager.instance.show_panel(UIManager.instance.character_panel)
	else:
		UIManager.instance.show_enemy_panel(selected_player.name)
